# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
# Copyright (c) 2026 Xudong Xu
"""Validate recorded output independently from the measurement renderer."""
import copy
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
loader = importlib.machinery.SourceFileLoader('demo_check', str(ROOT / 'Scripts/check-demo'))
spec = importlib.util.spec_from_loader(loader.name, loader)
checker = importlib.util.module_from_spec(spec)
loader.exec_module(checker)


class DemoRecordTests(unittest.TestCase):
    def setUp(self):
        assets = ROOT / 'Documentation/Assets'
        self.record = json.loads((assets / 'Demo-record.json').read_text())
        self.provenance = json.loads((assets / 'Demo-provenance.json').read_text())
        self.measurement = json.loads((ROOT / 'Documentation/InterfaceSize.json').read_text())

    def test_mixed_measurement_extractors_and_new_renderer_are_valid(self):
        self.measurement['extractorVersions'] = ['0.2.0', '0.3.1']
        self.measurement['rendererVersion'] = '0.3.1'
        checker.validate_record(self.record, self.provenance, self.measurement)
        version = self.provenance['extractor_version']
        self.record['commands'][1]['stdout'] = self.record['commands'][1]['stdout'].replace(
            'Extractor: ' + version, 'Extractor: 0.3.1')
        self.provenance['extractor_version'] = '0.3.1'
        checker.validate_record(self.record, self.provenance, self.measurement)

    def test_recorded_extractor_must_match_provenance(self):
        self.provenance['extractor_version'] = '0.0.0'
        with self.assertRaises(SystemExit):
            checker.validate_record(self.record, self.provenance, self.measurement)

    def test_input_revision_must_match_measurement(self):
        self.provenance['package_revision'] = '0' * 40
        with self.assertRaises(SystemExit):
            checker.validate_record(self.record, self.provenance, self.measurement)

    def test_unsuccessful_or_missing_commands_are_rejected(self):
        for commands in [self.record['commands'][:1], copy.deepcopy(self.record['commands'])]:
            if len(commands) == 2:
                commands[0]['exit_code'] = 1
            with self.assertRaises(SystemExit):
                checker.validate_record({'commands': commands}, self.provenance, self.measurement)


if __name__ == '__main__':
    unittest.main()
