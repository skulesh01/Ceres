# Журнал Решения Проблем

## 1. Docker Desktop: Virtualization support not detected
**Симптомы:** Docker Desktop не запускается, ошибка "Virtualization support not detected".
**Причина:** Отключена аппаратная виртуализация (VT-x/SVM) в BIOS.
**Решение:**
1. Перезагрузка в BIOS.
2. Включение `Intel Virtualization Technology` или `SVM Mode`.
3. Проверка в Диспетчере задач -> Производительность -> ЦП -> Виртуализация: Включено.
