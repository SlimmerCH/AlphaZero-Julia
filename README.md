# AlphaZero-Julia
AlphaZero Julia erfordert eine NVIDIA Grafikkarte und folgend Bibliotheken:

-	**FLUX**	- Neuronales Netzwerk
-	**CUDA** - Grafikkarten-Rechnungen
-	**BSON** - Speichern und laden der Parameter
-	**ProgressMeter** -	Anzeigen des Fortschrittes
-	**Plots**	- Darstellung der Policy mit Diagrammen

Möglicherweise läuft das Programm auch auf AMD-Grafikkarten mit der AMDGPU Bibliothek.

#### Nutzung der KI

- Die Parameter werden in **model.bson** gespeichert. Um diese zurückzusetzen, kann diese Datei gelöscht werden.

- Das Training kann mit **train.jl** gestartet werden.

- Das Experiment in Kapitel 5.1 kann in **performance.jl** reproduziert werden.

- Es kann gegen die KI mithilfe **humanvsai.jl** gespielt werden.
