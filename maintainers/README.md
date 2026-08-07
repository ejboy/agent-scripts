# Maintaining releases

The root `VERSION` is the canonical release version. Public scripts embed that version so copied files retain their identity and provenance. Update all registered scripts and run validation with:

```bash
./maintainers/bump-version 0.2.0
```

The maintainer command updates files and shows the resulting diff; it does not commit or tag the release.
