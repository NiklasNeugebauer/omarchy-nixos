Upstream **v4.0.2 → v4.0.3**.

<details><summary>vendored — ships as-is, but the modules reference these trees by path (60 files)</summary>

```
bin/omarchy
bin/omarchy-agent
bin/omarchy-apply-lock
bin/omarchy-default-agent
bin/omarchy-display-text-size
bin/omarchy-font-set
bin/omarchy-hibernation-setup
bin/omarchy-install-ai-hermes
bin/omarchy-install-ai-openclaw
bin/omarchy-install-ai-t3-code
bin/omarchy-install-hermes-cli
bin/omarchy-install-openclaw-cli
bin/omarchy-launch-1password
bin/omarchy-launch-openclaw
bin/omarchy-mise-install
bin/omarchy-openclaw-onboard
bin/omarchy-pkg-aur-install
bin/omarchy-provision-user
bin/omarchy-remove-ai-hermes
bin/omarchy-remove-ai-openclaw
bin/omarchy-remove-ai-perplexity
bin/omarchy-remove-ai-t3-code
bin/omarchy-remove-preinstalls
bin/omarchy-setup-security-fingerprint
bin/omarchy-sudo-passwordless
bin/omarchy-theme-set
bin/omarchy-theme-set-hermes
bin/omarchy-theme-set-t3code
bin/omarchy-toggle-hybrid-gpu
bin/omarchy-upgrade-to-quattro
config/kitty/kitty.conf
default/fonts/omarchy/README.md
default/fonts/omarchy/omarchy.ttf
default/hypr/apps/hermes.lua
default/omarchy/launcher.hides
default/omarchy/omarchy-menu.jsonc
default/systemd/system-sleep/force-igpu
default/systemd/system-sleep/keyboard-backlight
default/systemd/system/plocate-updatedb.service.d/10-omarchy.conf
default/themed/hermes.yaml.tpl
default/themed/t3code.json.tpl
shell/README.md
shell/Ui/PluginBarApi.qml
shell/Ui/qmldir
shell/plugins/README.md
shell/plugins/bar/Bar.qml
shell/plugins/lock/manifest.json
shell/plugins/panels/clock/Panel.qml
shell/plugins/panels/weather/Panel.qml
shell/plugins/polkit/manifest.json
shell/plugins/services/idle/Service.qml
shell/services/AuthServiceStore.js
shell/services/PluginAppLibraryApi.qml
shell/services/PluginBarStateApi.qml
shell/services/PluginBarWidgetRegistryApi.qml
shell/services/PluginFirstPartyServiceApi.qml
shell/services/PluginRegistry.qml
shell/services/PluginRegistryApi.qml
shell/services/PluginShellApi.qml
shell/shell.qml
```

</details>

<details><summary>package — translate into modules/omarchy/packages.nix and the inventory (1 files)</summary>

```
install/omarchy-other.packages
```

</details>

<details><summary>script — translate into a modules/omarchy/*.nix option (never executed) (8 files)</summary>

```
etc/mise/conf.d/omarchy.toml
etc/tmpfiles.d/omarchy-nopasswd-sudo.conf
etc/xdg/kitty/kitty.conf
install/config/all.sh
install/config/locate.sh
install/hardware/fix-bcm43xx.sh
install/post-install/localdb.sh
install/user/mise.sh
```

</details>

<details><summary>ignore — not shipped, or no NixOS meaning (62 files)</summary>

```
agents/skills/icon-font.md
agents/skills/shell-dev.md
docs/file-layout.md
docs/omarchy-shell.md
manual/17-ai.md
manual/32-shell-plugins.md
manual/48-security.md
migrations/1784809451.sh
migrations/1785090473.sh
migrations/1787215483.sh
migrations/1787760281.sh
migrations/1787843905.sh
migrations/1788577553.sh
migrations/1788619462.sh
migrations/1788662350.sh
migrations/1788724825.sh
migrations/1788745941.sh
migrations/1788848726.sh
test/shell.d/app-search-test.sh
test/shell.d/apply-lock-test.sh
test/shell.d/config-test.sh
test/shell.d/default-agent-test.sh
test/shell.d/fingerprint-driver-migration-test.sh
test/shell.d/fingerprint-package-test.sh
test/shell.d/fixtures/kitty/check-config.py
test/shell.d/fixtures/kitty/legacy.conf
test/shell.d/fixtures/legacy-icon-font/README.md
test/shell.d/fixtures/legacy-icon-font/omarchy.ttf
test/shell.d/fixtures/plugin-auth-boundary/AuthStoreOwner.qml
test/shell.d/fixtures/plugin-auth-boundary/AuthStoreReader.qml
test/shell.d/fixtures/plugin-auth-boundary/shell.qml
test/shell.d/fixtures/plugin-registry/shell.qml
test/shell.d/hermes-cli-migration-test.sh
test/shell.d/hermes-cli-test.sh
test/shell.d/hermes-desktop-install-test.sh
test/shell.d/hermes-remove-test.sh
test/shell.d/hermes-skills-migration-test.sh
test/shell.d/hermes-skin-migration-test.sh
test/shell.d/hermes-theme-test.sh
test/shell.d/kitty-config-test.sh
test/shell.d/launch-1password-test.sh
test/shell.d/launch-openclaw-test.sh
test/shell.d/legacy-icon-font-migration-test.sh
test/shell.d/locate-test.sh
test/shell.d/menu-test.sh
test/shell.d/mise-install-test.sh
test/shell.d/nopasswd-sudo-expiry-test.sh
test/shell.d/openclaw-onboard-test.sh
test/shell.d/plugin-auth-boundary-test.sh
test/shell.d/plugin-auth-lifecycle-test.sh
test/shell.d/plugin-indicators-clone-test.sh
test/shell.d/plugins-test.sh
test/shell.d/preinstalls-test.sh
test/shell.d/provision-user-test.sh
test/shell.d/release-ai-port-test.sh
test/shell.d/remove-ai-test.sh
test/shell.d/runtime-smoke-test.sh
test/shell.d/system-sleep-ownership-migration-test.sh
test/shell.d/t3code-install-test.sh
test/shell.d/theme-staging-test.sh
test/shell.d/unowned-system-paths-test.sh
test/shell.d/upgrade-to-quattro-test.sh
```

</details>

