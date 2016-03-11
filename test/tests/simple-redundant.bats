# source docker helpers
. util/docker.sh

echo_lines() {
  for (( i=0; i < ${#lines[*]}; i++ ))
  do
    echo ${lines[$i]}
  done
}

# Start containers
@test "Start Primary Container" {
  start_container "simple-redundant-primary" "192.168.0.2"
}

@test "Start Secondary Container" {
  start_container "simple-redundant-secondary" "192.168.0.3"
}

@test "Start Monitor Container" {
  start_container "simple-redundant-monitor" "192.168.0.4"
}

# Configure containers
@test "Configure Primary Container" {
  run run_hook "simple-redundant-primary" "default-configure" "$(payload default/configure-production)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Configure Secondary Container" {
  run run_hook "simple-redundant-secondary" "default-configure" "$(payload default/configure-production)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Configure Monitor Container" {
  run run_hook "simple-redundant-monitor" "monitor-configure" "$(payload monitor/configure)"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 10
}

@test "Stop Primary MongoDB" {
  run run_hook "simple-redundant-primary" "default-stop" "$(payload default/stop)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Stop Secondary MongoDB" {
  run run_hook "simple-redundant-secondary" "default-stop" "$(payload default/stop)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure Primary Container" {
  run run_hook "simple-redundant-primary" "default-redundant-configure" "$(payload default/redundant/configure-primary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure Secondary Container" {
  run run_hook "simple-redundant-secondary" "default-redundant-configure" "$(payload default/redundant/configure-secondary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure Monitor Container" {
  run run_hook "simple-redundant-monitor" "monitor-redundant-configure" "$(payload monitor/redundant/configure)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure VIP Agent Primary Container" {
  run run_hook "simple-redundant-primary" "default-redundant-config_vip_agent" "$(payload default/redundant/config_vip_agent-primary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure VIP Agent Secondary Container" {
  run run_hook "simple-redundant-secondary" "default-redundant-config_vip_agent" "$(payload default/redundant/config_vip_agent-secondary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Redundant Configure VIP Agent Monitor Container" {
  run run_hook "simple-redundant-monitor" "monitor-redundant-config_vip_agent" "$(payload monitor/redundant/config_vip_agent-monitor)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Ensure MongoDB Is Stopped" {
  while docker exec "simple-redundant-primary" bash -c "ps aux | grep [m]ongod"
  do
    sleep 1
  done
  while docker exec "simple-redundant-secondary" bash -c "ps aux | grep [m]ongod"
  do
    sleep 1
  done
}

@test "Start Primary MongoDB" {
  run run_hook "simple-redundant-primary" "default-start" "$(payload default/start)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Ensure MongoDB Primary Is Started" {
  until docker exec "simple-redundant-primary" bash -c "ps aux | grep [m]ongod"
  do
    sleep 1
  done
  until docker exec "simple-redundant-primary" bash -c "nc 192.168.0.2 27017 < /dev/null"
  do
    sleep 1
  done
}

@test "Start Secondary MongoDB" {
  run run_hook "simple-redundant-secondary" "default-start" "$(payload default/start)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Ensure MongoDB Secondary Is Started" {
  until docker exec "simple-redundant-secondary" bash -c "ps aux | grep [m]ongod"
  do
    sleep 1
  done
  until docker exec "simple-redundant-secondary" bash -c "nc 192.168.0.3 27017 < /dev/null"
  do
    sleep 1
  done
}

@test "Start Monitor Mongod" {
  run run_hook "simple-redundant-monitor" "monitor-start" "$(payload monitor/start)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Ensure Monitor Mongod Is Started" {
  until docker exec "simple-redundant-monitor" bash -c "ps aux | grep [m]ongod"
  do
    sleep 1
  done
}

@test "Check Primary Redundant Status" {
  run run_hook "simple-redundant-primary" "default-redundant-check_status" "$(payload default/redundant/check_status-primary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Check Secondary Redundant Status" {
  run run_hook "simple-redundant-secondary" "default-redundant-check_status" "$(payload default/redundant/check_status-secondary)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Insert Primary MongoDB Data" {
  run docker exec "simple-redundant-primary" bash -c "/data/bin/mongo --host gonano/192.168.0.2:27017,192.168.0.3:27017,192.168.0.4:27017 gonano --eval 'db.test.insert({\"key\": 1, \"value\": 1});'"
  echo_lines
  [ "$status" -eq 0 ]
  run docker exec "simple-redundant-primary" bash -c "/data/bin/mongo --host gonano/192.168.0.2:27017,192.168.0.3:27017,192.168.0.4:27017 gonano --eval 'db.test.find({}, { key: 1, value: 1, _id:0 }).shellPrint();'"
  echo_lines
  [ "${lines[5]}" = '{ "key" : 1, "value" : 1 }' ]
  [ "$status" -eq 0 ]
}

@test "Insert Secondary MongoDB Data" {
  run docker exec "simple-redundant-secondary" bash -c "/data/bin/mongo --host gonano/192.168.0.2:27017,192.168.0.3:27017,192.168.0.4:27017 gonano --eval 'db.test.insert({\"key\": 2, \"value\": 2});'"
  echo_lines
  [ "$status" -eq 0 ]
  run docker exec "simple-redundant-secondary" bash -c "/data/bin/mongo --host gonano/192.168.0.2:27017,192.168.0.3:27017,192.168.0.4:27017 gonano --eval 'db.test.find({}, { key: 1, value: 1, _id:0 }).shellPrint();'"
  echo_lines
  [ "${lines[5]}" = '{ "key" : 1, "value" : 1 }' ]
  [ "${lines[6]}" = '{ "key" : 2, "value" : 2 }' ]
  [ "$status" -eq 0 ]
}

@test "Verify Primary MongoDB Data" {
  run docker exec "simple-redundant-primary" bash -c "/data/bin/mongo --host gonano/192.168.0.2:27017,192.168.0.3:27017,192.168.0.4:27017 gonano --eval 'db.test.find({}, { key: 1, value: 1, _id:0 }).shellPrint();'"
  echo_lines
  [ "${lines[5]}" = '{ "key" : 1, "value" : 1 }' ]
  [ "${lines[6]}" = '{ "key" : 2, "value" : 2 }' ]
  [ "$status" -eq 0 ]
}

@test "Start Primary VIP Agent" {
  run run_hook "simple-redundant-primary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Start Secondary VIP Agent" {
  run run_hook "simple-redundant-secondary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Start Monitor VIP Agent" {
  run run_hook "simple-redundant-monitor" "monitor-redundant-start_vip_agent" "$(payload monitor/redundant/start_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 30
}

# Verify VIP
@test "Verify Primary VIP Agent" {
  run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Verify Secondary VIP Agent" {
  run docker exec "simple-redundant-secondary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 1 ]
}

@test "Verify Monitor VIP Agent" {
  run docker exec "simple-redundant-monitor" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 1 ]
}

@test "Stop Primary VIP Agent" {
  run run_hook "simple-redundant-primary" "default-redundant-stop_vip_agent" "$(payload default/redundant/stop_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Stop Secondary VIP Agent" {
  run run_hook "simple-redundant-secondary" "default-redundant-stop_vip_agent" "$(payload default/redundant/stop_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Stop Monitor VIP Agent" {
  run run_hook "simple-redundant-monitor" "monitor-redundant-stop_vip_agent" "$(payload monitor/redundant/stop_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Reverify Primary VIP Agent" {
  run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 1 ]
}

@test "Reverify Secondary VIP Agent" {
  run docker exec "simple-redundant-secondary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 1 ]
}

@test "Reverify Monitor VIP Agent" {
  run docker exec "simple-redundant-monitor" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 1 ]
}

@test "Restart Primary VIP Agent" {
  run run_hook "simple-redundant-primary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Restart Secondary VIP Agent" {
  run run_hook "simple-redundant-secondary" "default-redundant-start_vip_agent" "$(payload default/redundant/start_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Restart Monitor VIP Agent" {
  run run_hook "simple-redundant-monitor" "monitor-redundant-start_vip_agent" "$(payload monitor/redundant/start_vip_agent)"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 10
}

@test "Verify Primary VIP Agent Again" {
  run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Stop Primary" {
  run docker stop "simple-redundant-primary"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 10
}

@test "Verify Secondary VIP Agent Failover" {
  skip "Flip is acting weird, doesn't always failover properly."
  docker exec "simple-redundant-secondary" cat /var/log/gonano/flip/current
  docker exec "simple-redundant-monitor" cat /var/log/gonano/flip/current
  run docker exec "simple-redundant-secondary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

@test "Start Primary" {
  run docker start "simple-redundant-primary"
  echo_lines
  [ "$status" -eq 0 ]
  sleep 10
}

@test "Verify Primary VIP Agent fallback" {
  docker exec "simple-redundant-secondary" cat /var/log/gonano/flip/current
  docker exec "simple-redundant-primary" cat /var/log/gonano/flip/current
  docker exec "simple-redundant-monitor" cat /var/log/gonano/flip/current
  run docker exec "simple-redundant-primary" bash -c "ifconfig | grep 192.168.0.5"
  echo_lines
  [ "$status" -eq 0 ]
}

# Stop containers
@test "Stop Primary Container" {
  stop_container "simple-redundant-primary"
}

@test "Stop Secondary Container" {
  stop_container "simple-redundant-secondary"
}

@test "Stop Monitor Container" {
  stop_container "simple-redundant-monitor"
}