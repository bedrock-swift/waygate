# Contributing to WayGate

## Issues

For bug reports, include your Swift version, operating system, what you expected, and the smallest steps that reproduce the problem. For packet changes, include the affected Bedrock release and a test for the expected bytes. For listener changes, include the transport and the stage where the connection fails.

## Pull requests

Keep each pull request focused. Explain what changed and how you checked it. Discuss larger protocol or public API changes in an issue first.

Build with Swift 6.1 or later and run `swift test`. Add focused tests when changing wire formats or session behavior.

Follow the surrounding Swift style. Keep necessary comments short, lowercase, and beside the relevant code. Use short, lowercase commit subjects.
