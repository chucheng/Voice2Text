# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec for PunctuationServer.app
Build: cd scripts && pyinstaller PunctuationServer.spec
Output: dist/PunctuationServer.app
"""

import sys
from pathlib import Path
from PyInstaller.utils.hooks import collect_submodules

block_cipher = None

# Collect transformers submodules that PyInstaller misses due to dynamic imports
hiddenimports = (
    collect_submodules('transformers.models.bert')
    + collect_submodules('transformers.tokenization_utils')
    + [
        'transformers.models.bert.modeling_bert',
        'transformers.models.bert.tokenization_bert',
        'transformers.models.bert.tokenization_bert_fast',
        'tokenizers',
    ]
)

# Exclude unnecessary torch backends to reduce bundle size
excludes = [
    'torch.distributions',
    'torch.testing',
    'torch.utils.tensorboard',
    # CUDA runtime binaries — not needed on macOS, but keep torch.cuda module
    # (torch.__init__ imports torch.cuda at startup even on non-CUDA platforms)
    'torch._C._cuda',
    'torch.backends.cudnn',
    # Other unnecessary backends
    'torch.backends.mkl',
    'torch.backends.mkldnn',
    'torch.backends.openmp',
    # Large unused transformers modules
    'transformers.models.gpt2',
    'transformers.models.t5',
    'transformers.models.llama',
    'transformers.models.whisper',
    # Test / dev dependencies
    'pytest',
    'IPython',
    'notebook',
    'matplotlib',
    'PIL',
    'cv2',
    'scipy',
    'sklearn',
    'pandas',
    'numpy.testing',
]

a = Analysis(
    ['punctuation_server.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='PunctuationServer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,  # No terminal window when launched as .app
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='PunctuationServer',
)

app = BUNDLE(
    coll,
    name='PunctuationServer.app',
    icon=None,
    bundle_identifier='com.voice2text.punctuation-server',
    info_plist={
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleName': 'PunctuationServer',
        'LSBackgroundOnly': True,  # Background-only app (no Dock icon)
        'NSHighResolutionCapable': True,
    },
)
