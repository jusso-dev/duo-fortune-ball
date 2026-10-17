# Sound credits

All sounds here are original to this project. They are synthesised from sine waves and filtered noise by `scripts/make_sounds.py`, with no samples or third party recordings. They are covered by the project's MIT licence.

| File | Used for | How it is made |
| --- | --- | --- |
| `pod-creak.wav` | The pod starting to open (iPhone Duo) | A train of short filtered noise clicks that slows down |
| `chime-yes.wav` | Revealing a yes answer | Two bell tones a major third apart, rising |
| `chime-maybe.wav` | Revealing a maybe or playful answer | One soft bell tone |
| `chime-no.wav` | Revealing a no answer | Two lower bell tones, falling |

To change a sound, edit the script and run `python3 scripts/make_sounds.py` from the repository root. The output is deterministic.
