# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
import importlib.machinery
import importlib.util
import os
import sys


class _LoaderShim:
    def __init__(self, loader, default_name):
        self._loader = loader
        self._default_name = default_name

    def load_module(self, fullname):
        name = fullname or self._default_name
        if name in sys.modules:
            return sys.modules[name]
        if hasattr(self._loader, 'load_module'):
            return self._loader.load_module(name)
        spec = importlib.util.spec_from_loader(name, self._loader)
        if spec is None:
            raise ImportError(name)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        self._loader.exec_module(module)
        return module


def _find_module(self, fullname, path=None):
    spec = self.find_spec(fullname)
    if spec is not None and spec.loader is not None:
        return _LoaderShim(spec.loader, fullname)

    base_path = getattr(self, 'path', None)
    if base_path:
        module_path = os.path.join(base_path, fullname + '.py')
        if os.path.isfile(module_path):
            loader = importlib.machinery.SourceFileLoader(fullname, module_path)
            return _LoaderShim(loader, fullname)
    return None


if not hasattr(importlib.machinery.FileFinder, 'find_module'):
    importlib.machinery.FileFinder.find_module = _find_module
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
