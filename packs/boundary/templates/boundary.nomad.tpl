job [[ template "job_name" . ]] {
  [[ template "region" . ]]
  datacenters = [[ .boundary.datacenters | toPrettyJson ]]
  group "boundary_controller" {
    count = [[ .boundary.controller_count ]]
    network {
      #Clients must have access to the Controller's port (default 9200)
      port "controller" {
        to = 9200
      }
      #Workers must have access to the Controller's port (default 9201)
      port "worker" {
        to = 9201
      }
      #Clients must have access to the Worker's port (default 9202)
      port "comm" {
        to = 9202
      }
    }

    task "boundary" {
      driver = "docker"

      config {
        image   = "hashicorp/boundary"
        volumes = [ "local/boundary.hcl:/boundary/boundary.hcl" ]
        ports = [
          "controller",
          "worker",
          "comm"
        ]
        ##TODO: Test IPC_LOCK again
        #cap_add = [ "IPC_LOCK" ]
        privileged = [[ .boundary.docker_privileged ]]
      }

      ##TODO: Optionally interpolate Postgres address via Consul service discovery/service mesh
      ##TODO: Optionally pull Postgres creds from Vault via DB secrets engine
      template {
        change_mode = "restart
        destination = "secrets/config.env"
        env         = true
        data        = <<EOF
BOUNDARY_POSTGRES_URL=postgresql://[[ .boundary.postgres_username ]]:[[ .boundary.postgres_password ]]@[[ .boundary.postgres_address ]]/postgres?sslmode=disable
EOF
      }

      # Boundary config file
      template {
        change_mode = "restart"
        destination = "local/boundary.hcl"
        data        = <<EOH
[[ .boundary.config_file ]]
EOH
      }
    }
  }
}
