PROFILE_DIR := archiso/releng
WORK_DIR    := work
OUT_DIR     := out

.PHONY: help prepare iso clean

help:
	@echo "Targets:"
	@echo "  prepare  - build AUR packages/larch-calamares, fetch wallpapers, wire up submodules"
	@echo "             (scripts/prepare-iso.sh; run once, and again whenever AUR packages/submodules bump)"
	@echo "  iso      - mkarchiso the profile into $(OUT_DIR)/"
	@echo "  clean    - remove $(WORK_DIR)/ (mkarchiso's incremental-build cache, see building-the-iso docs"
	@echo "             for why a stale one can silently ship an unchanged ISO)"

prepare:
	./scripts/prepare-iso.sh

iso:
	sudo mkarchiso -v -w $(WORK_DIR) -o $(OUT_DIR) $(PROFILE_DIR)

clean:
	sudo rm -rf $(WORK_DIR)
