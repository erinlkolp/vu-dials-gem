# Changelog

## [0.1.0] - 2026-07-21

### Added
- Initial release. Ruby port of the `vudials_client` Python module.
- `VuDials::Dial` — dial control (value, color, background image, name, easing).
- `VuDials::Admin` — server admin (dial provisioning, API key lifecycle).
- Error hierarchy: `VuDials::Error`, `HTTPError`, `ConnectionError`.
