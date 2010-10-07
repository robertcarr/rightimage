@lb_test

Feature: Rails Server Test
  Tests the Rails servers

Scenario: Rails server test

  Given A deployment
  
  When I setup deployment input "MASTER_DB_DNSNAME" to "tester_ip"

  When I launch the "Front End" servers
  Then the "Front End" servers become operational

  When I setup deployment input "LB_HOSTNAME" to current "Front End"

  When I launch the "App Server" servers
  Then the "App Server" servers become operational

  Given I am testing the "App Server"
  Given I am using port "8000"
  Then I should see "html serving succeeded." from "/index.html" on the servers
  Then I should see "configuration=succeeded" from "/appserver/" on the servers
  Then I should see "I am in the db" from "/dbread/" on the servers
  Then I should see "hostname=" from "/serverid/" on the servers

  Given with a known OS
  Given I am testing the "App Server"
  When I force log rotation
#  Then I should see rotated apache log "access.log.1" in base dir "/mnt/log"

  Given I am testing the "App Server"
  When I reboot the servers
  Then the "App Server" servers become operational

  Then I should see "html serving succeeded." from "/index.html" on the servers
  Then I should see "configuration=succeeded" from "/appserver/" on the servers
  Then I should see "I am in the db" from "/dbread/" on the servers

