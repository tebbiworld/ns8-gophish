*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Test Cases ***
Back up the module
    ${repo}    ${path} =    Back up the module to the cluster repository    ${module_id}
    Set Global Variable    ${BACKUP_REPO}    ${repo}
    Set Global Variable    ${BACKUP_PATH}    ${path}

Restore into a new instance
    ${rid} =    Restore the module from the cluster repository    ${BACKUP_REPO}    ${BACKUP_PATH}
    Set Global Variable    ${restored_id}    ${rid}
    Should Not Be Equal    ${restored_id}    ${module_id}

The restored instance has its settings and database
    ${cfg} =    Run task    module/${restored_id}/get-configuration    {}
    Should Be Equal    ${cfg['admin_host']}    gophish.ci.test
    Should Be Equal    ${cfg['contact_address']}    ci@ci.test
    Wait Until Keyword Succeeds    30 times    10 seconds    Restored database is initialised

*** Keywords ***
Restored database is initialised
    ${cfg} =    Run task    module/${restored_id}/get-configuration    {}
    Should Be True    ${cfg['container_running']}
    Should Be True    ${cfg['db_initialized']}
