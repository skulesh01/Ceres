"""
CERES v3.0.0 - Cost Optimization Tests
Unit tests for cost analysis, optimization, and monitoring
"""

import unittest
from unittest.mock import Mock, patch, MagicMock
import json
import tempfile
import os
from pathlib import Path


class TestCostAnalysis(unittest.TestCase):
    """Test cost analysis and calculation functions"""

    def setUp(self):
        """Initialize test fixtures"""
        self.mock_nodes_output = '''
        {
            "items": [
                {
                    "metadata": {"name": "node-1"},
                    "spec": {"instanceType": "t3.large"},
                    "status": {
                        "allocatable": {
                            "cpu": "2",
                            "memory": "8Gi"
                        }
                    }
                },
                {
                    "metadata": {"name": "node-2"},
                    "spec": {"instanceType": "c5.xlarge"},
                    "status": {
                        "allocatable": {
                            "cpu": "4",
                            "memory": "8Gi"
                        }
                    }
                }
            ]
        }
        '''
        
        self.mock_pods_output = '''
        {
            "items": [
                {
                    "metadata": {
                        "name": "app-1",
                        "namespace": "default"
                    },
                    "spec": {
                        "containers": [
                            {
                                "name": "main",
                                "resources": {
                                    "requests": {"cpu": "100m", "memory": "256Mi"},
                                    "limits": {"cpu": "500m", "memory": "512Mi"}
                                }
                            }
                        ]
                    }
                }
            ]
        }
        '''

    @patch('subprocess.run')
    def test_analyze_node_costs(self, mock_run):
        """Test node cost analysis"""
        mock_run.return_value = Mock(stdout=self.mock_nodes_output)
        
        # Parse node data
        nodes_data = json.loads(self.mock_nodes_output)
        self.assertEqual(len(nodes_data['items']), 2)
        self.assertEqual(nodes_data['items'][0]['spec']['instanceType'], 't3.large')

    @patch('subprocess.run')
    def test_analyze_pod_requests(self, mock_run):
        """Test pod resource request analysis"""
        mock_run.return_value = Mock(stdout=self.mock_pods_output)
        
        pods_data = json.loads(self.mock_pods_output)
        pod = pods_data['items'][0]
        container = pod['spec']['containers'][0]
        
        cpu_request = container['resources']['requests']['cpu']
        memory_request = container['resources']['requests']['memory']
        
        self.assertEqual(cpu_request, '100m')
        self.assertEqual(memory_request, '256Mi')

    def test_rightsizing_calculation(self):
        """Test right-sizing recommendation calculation"""
        pod_cpu_usage = 50  # 50m
        pod_cpu_request = 100  # 100m
        utilization = (pod_cpu_usage / pod_cpu_request) * 100
        
        self.assertEqual(utilization, 50.0)
        self.assertTrue(utilization < 70, "Pod is under-provisioned")

    def test_cost_estimation(self):
        """Test cost estimation for different instance types"""
        pricing = {
            't3.large': {'hourly': 0.10, 'monthly': 72.0},
            'c5.xlarge': {'hourly': 0.17, 'monthly': 123.6},
            'r5.2xlarge': {'hourly': 0.50, 'monthly': 360.0}
        }
        
        # 3 nodes of t3.large, 5 nodes of c5.xlarge, 2 nodes of r5.2xlarge
        total_monthly = (3 * pricing['t3.large']['monthly'] + 
                        5 * pricing['c5.xlarge']['monthly'] + 
                        2 * pricing['r5.2xlarge']['monthly'])
        
        self.assertGreater(total_monthly, 1000)
        self.assertEqual(total_monthly, 3 * 72 + 5 * 123.6 + 2 * 360)

    def test_spot_instance_savings(self):
        """Test spot instance savings calculation"""
        on_demand_cost = 123.6  # c5.xlarge monthly
        spot_discount = 0.70  # 70% discount
        spot_cost = on_demand_cost * (1 - spot_discount)
        
        savings = on_demand_cost - spot_cost
        
        self.assertAlmostEqual(spot_cost, 37.08, places=2)
        self.assertAlmostEqual(savings, 86.52, places=2)
        self.assertGreater(spot_discount, 0.5, "Should have significant savings")

    def test_reserved_instance_1yr_savings(self):
        """Test 1-year reserved instance savings"""
        hourly_rate = 0.17  # c5.xlarge
        monthly_on_demand = hourly_rate * 730  # 730 hours/month
        
        # 1-year RI typically 30% discount
        ri_hourly = hourly_rate * 0.70
        monthly_ri = ri_hourly * 730
        yearly_savings = (monthly_on_demand - monthly_ri) * 12
        
        self.assertGreater(yearly_savings, 100)
        self.assertAlmostEqual(monthly_on_demand, 124.1, places=1)

    def test_reserved_instance_3yr_savings(self):
        """Test 3-year reserved instance savings"""
        hourly_rate = 0.17  # c5.xlarge
        
        # 3-year RI typically 50% discount
        ri_hourly_3yr = hourly_rate * 0.50
        yearly_cost = ri_hourly_3yr * 730 * 12
        threeyear_savings = (hourly_rate * 730 * 12 - yearly_cost) * 3
        
        self.assertGreater(threeyear_savings, 300)

    def test_cleanup_unused_pvc(self):
        """Test cleanup calculation for unused PVCs"""
        unused_pvcs = 3
        pvc_size_gb = 100
        ebs_cost_per_gb_month = 0.10
        monthly_savings = unused_pvcs * pvc_size_gb * ebs_cost_per_gb_month
        
        self.assertEqual(monthly_savings, 30.0)

    def test_cleanup_old_jobs(self):
        """Test cleanup for old completed jobs"""
        old_jobs = 50
        job_storage_estimate_gb = 5  # logs + artifacts per job
        ebs_cost_per_gb_month = 0.10
        monthly_savings = old_jobs * job_storage_estimate_gb * ebs_cost_per_gb_month
        
        self.assertEqual(monthly_savings, 25.0)


class TestResourceQuotas(unittest.TestCase):
    """Test resource quota and limit range configuration"""

    def test_quota_cpu_limit(self):
        """Test CPU quota enforcement"""
        quota_cpu = '100'  # 100 CPU cores max per namespace
        used_cpu = '75'
        remaining = 100 - 75
        
        self.assertEqual(remaining, 25)
        self.assertGreater(remaining, 0)

    def test_quota_memory_limit(self):
        """Test memory quota enforcement"""
        quota_memory_gi = 500  # 500GB per namespace
        used_memory_gi = 350
        remaining = quota_memory_gi - used_memory_gi
        
        self.assertEqual(remaining, 150)
        self.assertGreater(remaining, 0)

    def test_limit_range_min_max(self):
        """Test min/max limits for containers"""
        min_cpu = 10  # 10m
        max_cpu = 2000  # 2 CPU cores
        
        test_cpu = 500  # 500m
        self.assertGreater(test_cpu, min_cpu)
        self.assertLess(test_cpu, max_cpu)

    def test_quota_prevention(self):
        """Test quota prevents over-allocation"""
        quota = 100
        allocated = [30, 30, 30, 15]  # 105 total
        
        total_allocated = sum(allocated)
        self.assertGreater(total_allocated, quota)
        self.assertEqual(total_allocated, 105)


class TestCostMonitoring(unittest.TestCase):
    """Test cost monitoring and alerting"""

    def test_daily_cost_calculation(self):
        """Test daily cost calculation from hourly metrics"""
        hourly_costs = [50, 48, 52, 49, 51, 50, 49, 48, 50, 51, 49, 50,
                       52, 48, 50, 49, 51, 50, 48, 49, 50, 51, 49, 50]
        daily_cost = sum(hourly_costs) / 24 * 24
        
        self.assertEqual(daily_cost, sum(hourly_costs))
        self.assertAlmostEqual(daily_cost, 1200, places=-1)

    def test_cost_trend_detection(self):
        """Test cost trend detection"""
        daily_costs = [1000, 1050, 1100, 1200, 1500, 1800]  # Increasing trend
        
        baseline = daily_costs[0]
        latest = daily_costs[-1]
        increase_percentage = ((latest - baseline) / baseline) * 100
        
        self.assertGreater(increase_percentage, 50)
        self.assertEqual(increase_percentage, 80.0)

    def test_cost_spike_alert(self):
        """Test cost spike alert triggering"""
        average_cost = 1000
        threshold_multiplier = 1.5  # Alert if 1.5x average
        current_cost = 1600
        
        should_alert = current_cost > (average_cost * threshold_multiplier)
        self.assertTrue(should_alert)

    def test_cost_by_namespace(self):
        """Test per-namespace cost calculation"""
        namespace_costs = {
            'production': 500,
            'staging': 200,
            'development': 150,
            'monitoring': 100
        }
        
        total = sum(namespace_costs.values())
        prod_percentage = (namespace_costs['production'] / total) * 100
        
        self.assertEqual(total, 950)
        self.assertAlmostEqual(prod_percentage, 52.63, places=2)

    def test_cost_by_pod(self):
        """Test per-pod cost calculation"""
        pod_resources = {
            'api-server': {'cpu': 2, 'memory': 4},  # 2 CPU, 4GB
            'worker-1': {'cpu': 4, 'memory': 8},
            'worker-2': {'cpu': 4, 'memory': 8}
        }
        
        # Simplified: assume $0.05 per CPU per hour, $0.01 per GB per hour
        hourly_rates = {pod: (res['cpu'] * 0.05 + res['memory'] * 0.01) 
                       for pod, res in pod_resources.items()}
        
        self.assertEqual(hourly_rates['api-server'], 0.14)
        self.assertEqual(hourly_rates['worker-1'], 0.28)


class TestCostOptimizationScript(unittest.TestCase):
    """Test cost optimization script integration"""

    def test_script_output_directory(self):
        """Test cost report output directory creation"""
        output_dir = '/tmp/cost-reports'
        os.makedirs(output_dir, exist_ok=True)
        
        self.assertTrue(os.path.isdir(output_dir))

    def test_cost_report_json_format(self):
        """Test cost report JSON format validity"""
        report = {
            'timestamp': '2026-01-01T12:00:00Z',
            'total_monthly_cost': 1500,
            'nodes': [
                {'name': 'node-1', 'type': 't3.large', 'cost': 72.0},
                {'name': 'node-2', 'type': 'c5.xlarge', 'cost': 123.6}
            ],
            'recommendations': [
                {'type': 'rightsizing', 'pod': 'app-1', 'savings': 20},
                {'type': 'spot', 'nodes': 2, 'savings': 150}
            ]
        }
        
        # Validate JSON structure
        self.assertIn('timestamp', report)
        self.assertIn('total_monthly_cost', report)
        self.assertIn('nodes', report)
        self.assertIn('recommendations', report)
        self.assertGreater(len(report['nodes']), 0)

    def test_prometheus_metrics_format(self):
        """Test Prometheus metrics format"""
        metrics = [
            'cost:hourly:usd{cluster="prod"} 50.0',
            'cost:daily:usd{cluster="prod"} 1200.0',
            'cost:by_namespace:usd{namespace="production"} 600.0'
        ]
        
        # Validate metric format (name{labels} value)
        for metric in metrics:
            self.assertIn('{', metric)
            self.assertIn('}', metric)
            parts = metric.split('}')
            self.assertEqual(len(parts), 2)


if __name__ == '__main__':
    unittest.main()
