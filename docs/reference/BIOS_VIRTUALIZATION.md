# Включение виртуализации (BIOS/UEFI) для Docker Desktop

Для корректной работы Docker Desktop на Windows требуется включить аппаратную виртуализацию (Intel VT-x / AMD SVM).

1. Перезагрузите компьютер и войдите в BIOS/UEFI (чаще клавиши Del, F2, F10, Esc).
2. Найдите опцию виртуализации и включите:
   - Intel: `Intel VT-x`, `VT-d` (если есть)
   - AMD: `SVM Mode` / `AMD-V`
3. Сохраните изменения и перезагрузитесь.
4. В Windows включите (по необходимости):
   - Hyper-V
   - Windows Hypervisor Platform

После этого Docker Desktop должен корректно обнаружить виртуализацию.
