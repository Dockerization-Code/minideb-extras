IMAGE_FLAVORS := minideb/jessie
GCLOUD_PROJECT := stacksmith-images
GCLOUD_SERVICE_KEY :=

.PHONY: all build cache push

all: build

build:
	@for f in $(IMAGE_FLAVORS); do \
		distro=$$(echo "$$f" | cut -d'/' -f1) ; \
		release=$$(echo "$$f" | cut -d'/' -f2) ; \
		revision=$$(cat $$release/REVISION) ; \
		if [ $(DEV_BUILD) ]; then revision=DEV; fi ; \
		docker build --rm=false -t gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release-r$$revision -f $$release/Dockerfile . && \
		echo "FROM gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release-r$$revision\n$$(cat $$release/buildpack/Dockerfile)" | docker build --rm=false -t gcr.io/$(GCLOUD_PROJECT)/$$distro-buildpack:$$release-r$$revision - ; \
		if [ "$$revision" != "DEV" ]; then \
			docker build --rm=false -t gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release -f $$release/Dockerfile . && \
			echo "FROM gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release\n$$(cat $$release/buildpack/Dockerfile)" | docker build --rm=false -t gcr.io/$(GCLOUD_PROJECT)/$$distro-buildpack:$$release - ; \
		fi ; \
	done

push: build
	@if [ -n "$(GCLOUD_SERVICE_KEY)" ]; then \
		echo $(GCLOUD_SERVICE_KEY) | base64 --decode > ${HOME}/gcloud-service-key.json ; \
		gcloud auth activate-service-account --key-file ${HOME}/gcloud-service-key.json ; \
		for f in $(IMAGE_FLAVORS); do \
			distro=$$(echo "$$f" | cut -d'/' -f1) ; \
			release=$$(echo "$$f" | cut -d'/' -f2) ; \
			revision=$$(cat $$release/REVISION) ; \
			if [ $(DEV_BUILD) ]; then revision=DEV; fi ; \
			gcloud docker -- push gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release-r$$revision ; \
			gcloud docker -- push gcr.io/$(GCLOUD_PROJECT)/$$distro-buildpack:$$release-r$$revision ; \
			if [ "$$revision" != "DEV" ]; then \
				gcloud docker -- push gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release ; \
				gcloud docker -- push gcr.io/$(GCLOUD_PROJECT)/$$distro-buildpack:$$release ; \
				if [ -n "$(STACKSMITH_API_KEY)" ]; then \
					export jessie_version=8.6 ; \
					sm_version=$$(printenv $${release}_version) ; \
					release_notes=$$(git log -1 --pretty=%b | cat | awk 1 ORS='\\n') ; \
					curl "https://stacksmith.bitnami.com/api/v1/components/$$distro/versions?api_key=$(STACKSMITH_API_KEY)" \
						-H 'Content-Type: application/json' \
						--data '{"version": "'"$$sm_version"'", "name": "'"$$release"'", "revision": "'"$$revision"'", "published": true, "release_notes": "'"$$release_notes"'", "release_notes_url": "https://github.com/bitnami/stacksmith-base/releases"}' ; \
				fi ; \
			fi ; \
		done ; \
	fi
