# import_slides.py
import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent
SLIDES_PATH = HERE / "deck_slides.py"

SLIDES_PATH = HERE / "./deck_slides.py"
spec = importlib.util.spec_from_file_location("deck_slides", SLIDES_PATH)
if spec is None or spec.loader is None:
    raise ImportError(f"Cannot load deck_slides from {SLIDES_PATH}")
S = importlib.util.module_from_spec(spec)
spec.loader.exec_module(S)

print("Loaded:", S.__file__)
print("Functions:", [n for n in dir(S) if n.startswith("add_")])
