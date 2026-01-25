package ui

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"os/exec"
	"sync"
	"time"
)

type JobStatus string

const (
	JobRunning JobStatus = "running"
	JobDone    JobStatus = "done"
	JobError   JobStatus = "error"
)

type Job struct {
	ID        string
	Name      string
	Command   []string
	Status    JobStatus
	StartedAt time.Time
	EndedAt   *time.Time
	ExitCode  *int
	Output    string
}

type JobManager struct {
	mu   sync.Mutex
	jobs map[string]*Job
}

func NewJobManager() *JobManager {
	return &JobManager{jobs: map[string]*Job{}}
}

func (m *JobManager) Get(id string) (*Job, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	j, ok := m.jobs[id]
	return j, ok
}

func (m *JobManager) List() []*Job {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]*Job, 0, len(m.jobs))
	for _, j := range m.jobs {
		out = append(out, j)
	}
	return out
}

func (m *JobManager) Start(name string, cmdArgs []string, workdir string, env []string) *Job {
	id := randomID(12)
	j := &Job{ID: id, Name: name, Command: append([]string{}, cmdArgs...), Status: JobRunning, StartedAt: time.Now()}

	m.mu.Lock()
	m.jobs[id] = j
	m.mu.Unlock()

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
		defer cancel()

		cmd := exec.CommandContext(ctx, cmdArgs[0], cmdArgs[1:]...)
		if workdir != "" {
			cmd.Dir = workdir
		}
		if len(env) != 0 {
			cmd.Env = env
		}

		stdout, _ := cmd.StdoutPipe()
		stderr, _ := cmd.StderrPipe()

		_ = cmd.Start()

		var bufMu sync.Mutex
		var out string
		appendLine := func(line string) {
			bufMu.Lock()
			out += line + "\n"
			bufMu.Unlock()
		}

		scan := func(rdr interface{ Read([]byte) (int, error) }) {
			s := bufio.NewScanner(rdr)
			for s.Scan() {
				appendLine(s.Text())
			}
		}

		if stdout != nil {
			go scan(stdout)
		}
		if stderr != nil {
			go scan(stderr)
		}

		err := cmd.Wait()

		exit := 0
		if err != nil {
			exit = 1
		}

		end := time.Now()
		m.mu.Lock()
		j.EndedAt = &end
		j.ExitCode = &exit
		if err != nil {
			j.Status = JobError
		} else {
			j.Status = JobDone
		}
		bufMu.Lock()
		j.Output = out
		bufMu.Unlock()
		m.mu.Unlock()
	}()

	return j
}

func randomID(nBytes int) string {
	b := make([]byte, nBytes)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
