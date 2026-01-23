KPT_RETRY ?= 5
KPT_RECONCILE_TIMEOUT ?= 3m
KPT_LIVE_APPLY_ARGS += --reconcile-timeout=$(KPT_RECONCILE_TIMEOUT)

# Override the INSTALL_KPT_PACKAGE macro
# 
# Set the --reconcile-timeout flag so that KPT doesn't just hang for a while
# then the updated macro below, will handle the exit by retrying the kpt live apply
# until we hit the retry limit.
define INSTALL_KPT_PACKAGE
	{	\
		echo -e "--> INSTALL: [\033[1;34m$2\033[0m] - Applying kpt package"									;\
		pushd $1 &>/dev/null || (echo "[ERROR]: Failed to switch cwd to $2" && exit 1)						;\
		if [[ ! -f resourcegroup.yaml ]] || [[ $(KPT_LIVE_INIT_FORCE) -eq 1 ]]; then						 \
			$(KPT) live init --force 2>&1 | $(INDENT_OUT)													;\
		else																								 \
			echo -e "--> INSTALL: [\033[1;34m$2\033[0m] - Resource group found, don't re-init this package"	;\
		fi																									;\
		for attempt in $$(seq 1 $(KPT_RETRY)); do \
			echo -e "--> INSTALL: [\033[1;34m$2\033[0m] - Attempt $$attempt/$(KPT_RETRY)"					;\
			if $(KPT) live apply $(KPT_LIVE_APPLY_ARGS) 2>&1 | $(INDENT_OUT); then \
				break																						;\
			fi																								;\
			if [[ $$attempt -eq $(KPT_RETRY) ]]; then \
				echo -e "--> INSTALL: [\033[1;31m$2\033[0m] - Failed after $(KPT_RETRY) attempts"			;\
				exit 1																						;\
			fi																								;\
			echo -e "--> INSTALL: [\033[1;33m$2\033[0m] - Attempt $$attempt failed after $(KPT_RECONCILE_TIMEOUT), retrying..."	;\
			sleep 2																							;\
		done																								;\
		popd &>/dev/null || (echo "[ERROR]: Failed to switch back from $2" && exit 1)						;\
		echo -e "--> INSTALL: [\033[0;32m$2\033[0m] - Applied and reconciled package"						;\
	}
endef

CODESPACES_ENGINECONFIG_CUSTOM_SETTINGS_PATCH := /eda-codespaces/engine-config-patch.yaml

.PHONY: patch-codespaces-engineconfig
patch-codespaces-engineconfig: | $(YQ) $(KPT_PKG) ## Patch the EngineConfig manifest to add codespaces custom settings
	@{	\
		echo "--> INFO: Patching EngineConfig manifest for codespaces"																			;\
		ENGINE_CONFIG_FILE="$(KPT_CORE)/engine-config/engineconfig.yaml"																		;\
		if [[ ! -f "$$ENGINE_CONFIG_FILE" ]]; then (echo "[ERROR] EngineConfig manifest not found at $$ENGINE_CONFIG_FILE" && exit 1); fi		;\
		$(YQ) eval '.spec.customSettings = load("$(CODESPACES_ENGINECONFIG_CUSTOM_SETTINGS_PATCH)").customSettings' -i "$$ENGINE_CONFIG_FILE"	;\
	}

.PHONY: configure-try-eda-params
configure-try-eda-params: | $(BASE) $(BUILD) $(KPT) $(KPT_SETTERS_TRY_EDA_FILE) patch-codespaces-engineconfig ## Configure parameters specific to try-eda

.PHONY: ls-ways-to-reach-api-server 
ls-ways-to-reach-api-server: | $(KUBECTL) configure-codespaces-keycloak

.PHONY: configure-codespaces-keycloak
configure-codespaces-keycloak: | $(KUBECTL) ## Configure Keycloak frontendUrl for GitHub Codespaces
	@if [ -n "$(CODESPACE_NAME)" ] && [ -n "$(GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN)" ]; then \
		CODESPACE_URL="https://$(CODESPACE_NAME)-$(EDA_PORT).$(GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN)" ;\
		KC_URL="https://eda-keycloak:9443/core/httpproxy/v1/keycloak" ;\
		echo "--> INFO: Configuring Keycloak frontendUrl for Codespaces..." ;\
		$(KUBECTL) wait --for=condition=ready pod -l eda.nokia.com/app=keycloak -n $(EDA_CORE_NAMESPACE) --timeout=300s ;\
		TOKEN=$$($(KUBECTL) exec -n $(EDA_CORE_NAMESPACE) deploy/eda-toolbox -- curl -sk -X POST \
			"$${KC_URL}/realms/master/protocol/openid-connect/token" \
			-d "username=admin" -d "password=admin" -d "grant_type=password" -d "client_id=admin-cli" | jq -r '.access_token') ;\
		$(KUBECTL) exec -n $(EDA_CORE_NAMESPACE) deploy/eda-toolbox -- curl -sk -X PUT \
			"$${KC_URL}/admin/realms/eda" \
			-H "Authorization: Bearer $${TOKEN}" \
			-H "Content-Type: application/json" \
			-d "{\"attributes\": {\"frontendUrl\": \"$${CODESPACE_URL}/core/httpproxy/v1/keycloak\"}}" ;\
		echo "--> INFO: Keycloak frontendUrl set to: $${CODESPACE_URL}/core/httpproxy/v1/keycloak" ;\
	else \
		echo "--> INFO: Not running in Codespaces, skipping Keycloak frontendUrl configuration" ;\
	fi

.PHONY: start-ui-port-forward
start-ui-port-forward:
	@{	\
		echo "--> Triggering browser window open 0.0.0.0:9443"	;\
	}