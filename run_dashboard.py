#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Excel Dashboard Generator - openpyxl tabanlı
"""
import subprocess
import sys

# openpyxl yüklü değilse, yükle
try:
    import openpyxl
except ImportError:
    print("openpyxl kurulumu başlıyor...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl", "-q"])

# Şimdi işlemi başlat
exec(open(r"D:\Dev\pusula\create_dashboard_v2.py").read())
