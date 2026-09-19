*** Settings ***
Library     SSHLibrary
Resource    api.resource

*** Variables ***
${CONFIG}    {"admin_host":"gophish.ci.test","phish_host":"","contact_address":"ci@ci.test","lets_encrypt":false,"http2https":true}

*** Test Cases ***
Install the module
    IF    '${SCENARIO}' == 'update'
        ${output}  ${rc} =    Execute Command    add-module ${UPDATE_FROM} 1    return_rc=True
    ELSE
        ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1    return_rc=True
    END
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Configure the module
    Run task    module/${module_id}/configure-module    ${CONFIG}    decode_json=${FALSE}

The admin interface answers behind Traefik
    Wait Until Keyword Succeeds    60 times    10 seconds    Admin login page is served

Update to the image under test
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}
    Run on node    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    Wait Until Keyword Succeeds    60 times    10 seconds    Admin login page is served

Configuration reads back
    ${cfg} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${cfg['admin_host']}    gophish.ci.test
    Should Be Equal    ${cfg['contact_address']}    ci@ci.test
    Should Be True    ${cfg['container_running']}

No secret in the module environment
    ${leaks} =    Run on node    redis-cli --raw HKEYS module/${module_id}/environment | grep -Eci "PASS|SECRET|TOKEN|API_KEY" || true
    Should Be Equal As Integers    ${leaks.strip()}    0

*** Keywords ***
Admin login page is served
    ${out} =    Run on node    curl -fsSkL -H 'Host: gophish.ci.test' https://127.0.0.1/login
    Should Contain    ${out}    Gophish
