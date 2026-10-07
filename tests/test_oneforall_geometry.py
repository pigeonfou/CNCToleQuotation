import json
import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT=Path(__file__).parents[1]/'core/geometry/analyze.py'

class GeometryTests(unittest.TestCase):
    def test_oneforall_never_silently_uses_synthetic_geometry(self):
        if runpy.run_path(str(SCRIPT))['HAS_OCC']:
            self.skipTest('A real OCC runtime is present; verify with a real STEP fixture.')
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'sample.step';p.write_text('ISO-10303-21;\nEND-ISO-10303-21;')
            result=subprocess.run([sys.executable,str(SCRIPT),str(p)],env={**os.environ,'CNCTOLE_ALLOW_FALLBACK':'0'},capture_output=True,text=True)
        data=json.loads(result.stdout)
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(data['success'])
        self.assertIn('OpenCascade requis',data['error'])

if __name__=='__main__':unittest.main()
