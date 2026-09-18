<!--
  Copyright (C) 2026 tebbi
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title"><h2>{{ $t("settings.title") }}</h2></cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification kind="error" :title="$t('action.get-configuration')" :description="error.getConfiguration" :showCloseButton="false" />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <!-- Live state -->
          <NsInlineNotification
            v-if="!loading.getConfiguration"
            :kind="container_running ? 'success' : 'info'"
            :title="container_running ? $t('settings.status_running', { version: gophish_version || '?' }) : $t('settings.status_stopped')"
            :showCloseButton="false"
            class="info-tile"
          />
          <div v-if="!loading.getConfiguration && admin_url" class="links">
            <a :href="admin_url" target="_blank" rel="noopener">{{ $t("settings.open_admin") }}: {{ admin_url }}</a>
          </div>
          <div v-if="!loading.getConfiguration && phish_url" class="links">
            <a :href="phish_url" target="_blank" rel="noopener">{{ $t("settings.open_phish") }}: {{ phish_url }}</a>
          </div>
          <NsInlineNotification
            v-if="!loading.getConfiguration && !phish_managed && phish_target"
            kind="info"
            :title="$t('settings.phish_manual_title')"
            :description="$t('settings.phish_manual_desc', { target: phish_target })"
            :showCloseButton="false"
            class="info-tile"
          />

          <!-- First-login credentials -->
          <NsInlineNotification
            v-if="!loading.getConfiguration && initial_password"
            kind="warning"
            :title="$t('settings.first_login_title')"
            :description="$t('settings.first_login_desc', { password: initial_password })"
            :showCloseButton="false"
            class="info-tile"
          />
          <NsInlineNotification
            v-else-if="!loading.getConfiguration && container_running && db_initialized"
            kind="info"
            :title="$t('settings.first_login_title')"
            :description="$t('settings.first_login_log')"
            :showCloseButton="false"
            class="info-tile"
          />

          <cv-form @submit.prevent="configureModule">
            <h4 class="section">{{ $t("settings.hosts_section") }}</h4>
            <cv-text-input :label="$t('settings.admin_host')" v-model.trim="admin_host" :placeholder="$t('settings.admin_host_placeholder')" :helper-text="$t('settings.admin_host_helper')" :disabled="busy" :invalid-message="$t(error.admin_host)" ref="admin_host" class="field"></cv-text-input>
            <cv-text-input :label="$t('settings.phish_host')" v-model.trim="phish_host" :placeholder="$t('settings.phish_host_placeholder')" :helper-text="$t('settings.phish_host_helper')" :disabled="busy" :invalid-message="$t(error.phish_host)" ref="phish_host" class="field"></cv-text-input>
            <div v-if="phish_target" class="bx--form__helper-text field-ref">
              {{ $t("settings.phish_target_ref", { target: phish_target }) }}
              <code>{{ phish_target }}</code>
            </div>
            <cv-toggle value="letsEncrypt" :label="$t('settings.lets_encrypt')" v-model="lets_encrypt" :disabled="busy" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>
            <cv-toggle value="http2https" :label="$t('settings.http2https')" v-model="http2https" :disabled="busy" class="toggle">
              <template slot="text-left">{{ $t("settings.disabled") }}</template>
              <template slot="text-right">{{ $t("settings.enabled") }}</template>
            </cv-toggle>

            <h4 class="section">{{ $t("settings.options_section") }}</h4>
            <cv-text-input :label="$t('settings.contact_address')" v-model.trim="contact_address" :placeholder="$t('settings.contact_address_placeholder')" :helper-text="$t('settings.contact_address_helper')" :disabled="busy" class="field"></cv-text-input>

            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification kind="error" :title="$t('action.configure-module')" :description="error.configureModule" :showCloseButton="false" />
              </cv-column>
            </cv-row>
            <NsButton kind="primary" :icon="Save20" :loading="loading.configureModule" :disabled="busy">{{ $t("settings.save") }}</NsButton>
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import { QueryParamService, UtilService, TaskService, IconService, PageTitleService } from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [TaskService, IconService, UtilService, QueryParamService, PageTitleService],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: { page: "settings" },
      urlCheckInterval: null,
      admin_host: "",
      phish_host: "",
      contact_address: "",
      lets_encrypt: false,
      http2https: true,
      admin_url: "",
      phish_url: "",
      phish_managed: true,
      phish_port: "",
      phish_target: "",
      container_running: false,
      db_initialized: false,
      initial_password: "",
      gophish_version: "",
      loading: { getConfiguration: false, configureModule: false },
      error: {
        getConfiguration: "", configureModule: "",
        admin_host: "", phish_host: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    busy() {
      return this.loading.getConfiguration || this.loading.configureModule;
    },
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  created() {
    this.getConfiguration();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();
      this.core.$root.$once(`${taskAction}-aborted-${eventId}`, this.getConfigurationAborted);
      this.core.$root.$once(`${taskAction}-completed-${eventId}`, this.getConfigurationCompleted);
      const res = await to(this.createModuleTaskForApp(this.instanceName, { action: taskAction, extra: { title: this.$t("action." + taskAction), isNotificationHidden: true, eventId } }));
      const err = res[0];
      if (err) {
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      this.loading.getConfiguration = false;
      const c = taskResult.output;
      this.admin_host = c.admin_host || "";
      this.phish_host = c.phish_host || "";
      this.contact_address = c.contact_address || "";
      this.lets_encrypt = !!c.lets_encrypt;
      this.http2https = c.http2https !== false;
      this.admin_url = c.admin_url || "";
      this.phish_url = c.phish_url || "";
      this.phish_managed = c.phish_managed !== false;
      this.phish_port = c.phish_port || "";
      this.phish_target = c.phish_target || "";
      this.container_running = !!c.container_running;
      this.db_initialized = !!c.db_initialized;
      this.initial_password = c.initial_password || "";
      this.gophish_version = c.gophish_version || "";
    },
    validateConfigureModule() {
      this.clearErrors(this);
      let ok = true;
      const fail = (field, msg) => {
        this.error[field] = msg;
        if (ok && this.$refs[field]) this.focusElement(field);
        ok = false;
      };
      const isHost = (h) => /\./.test(h) && /^[A-Za-z0-9.-]+$/.test(h);
      if (!isHost(this.admin_host)) fail("admin_host", "settings.invalid_host");
      if (this.phish_host && !isHost(this.phish_host)) fail("phish_host", "settings.invalid_host");
      if (this.phish_host && this.admin_host && this.admin_host.toLowerCase() === this.phish_host.toLowerCase()) fail("phish_host", "settings.hosts_must_differ");
      return ok;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusSet = false;
      for (const e of validationErrors) {
        if (e.field !== "(root)") {
          const detail = e.value && typeof e.value === "string" ? ` (${e.value})` : "";
          this.error[e.field] = this.$t("settings." + e.error) + detail;
          if (!focusSet && this.$refs[e.field]) {
            this.focusElement(e.field);
            focusSet = true;
          }
        }
      }
    },
    async configureModule() {
      if (!this.validateConfigureModule()) return;
      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();
      this.core.$root.$once(`${taskAction}-aborted-${eventId}`, this.configureModuleAborted);
      this.core.$root.$once(`${taskAction}-validation-failed-${eventId}`, this.configureModuleValidationFailed);
      this.core.$root.$once(`${taskAction}-completed-${eventId}`, this.configureModuleCompleted);
      const data = {
        admin_host: this.admin_host,
        phish_host: this.phish_host,
        contact_address: this.contact_address,
        lets_encrypt: this.lets_encrypt,
        http2https: this.http2https,
      };
      const res = await to(this.createModuleTaskForApp(this.instanceName, {
        action: taskAction,
        data,
        extra: { title: this.$t("settings.configure_instance", { instance: this.instanceName }), description: this.$t("common.processing"), eventId },
      }));
      const err = res[0];
      if (err) {
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.field { margin-top: $spacing-06; }
.toggle { margin-top: $spacing-06; }
.info-tile { margin-top: $spacing-06; }
.links { margin-top: $spacing-04; }
.field-ref { margin-top: $spacing-03; }
.field-ref code { user-select: all; }
.section { margin-top: $spacing-07; margin-bottom: $spacing-03; }
</style>
