def main(ctx):

  build = {
      "name": "build",
      "image": "mcr.microsoft.com/dotnet/sdk:7.0",
      "commands": [
        "cd Sources/",
        "dotnet restore OpenLibraryWS_Wrapper.sln",
        "dotnet build OpenLibraryWS_Wrapper.sln"
      ]
    }
  test = {
    "name": "test",
    "image": "mcr.microsoft.com/dotnet/sdk:7.0",
    "commands": [
      "cd Sources/",
      "dotnet restore OpenLibraryWS_Wrapper.sln",
      "dotnet test OpenLibraryWS_Wrapper.sln"
    ]
  }
    
  code_inspection = {
    "name": "code-inspection",
    "image": "hub.codefirst.iut.uca.fr/marc.chevaldonne/codefirst-dronesonarplugin-dotnet7",
    "secrets": ["SECRET_SONAR_LOGIN"],
    "settings":{
      "sonar_host": "https://codefirst.iut.uca.fr/sonar/",
      "sonar_token": {
        "from_secret": "SECRET_SONAR_LOGIN"
      }
    },
    "commands": [
      "cd Sources/",
      "dotnet restore OpenLibraryWS_Wrapper.sln",
      'dotnet sonarscanner begin /k:CICD_3A_CorentinRICHARD_dotnet /d:sonar.host.url=$${PLUGIN_SONAR_HOST} /d:sonar.coverageReportPaths="coveragereport/SonarQube.xml" /d:sonar.coverage.exclusions="Tests/**" /d:sonar.login=$${PLUGIN_SONAR_TOKEN}', 
      'dotnet build OpenLibraryWS_Wrapper.sln -c Release --no-restore',
      'dotnet test OpenLibraryWS_Wrapper.sln --logger trx --no-restore /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura --collect "XPlat Code Coverage"',
      'reportgenerator -reports:"**/coverage.cobertura.xml" -reporttypes:SonarQube -targetdir:"coveragereport"',
      'dotnet publish OpenLibraryWS_Wrapper.sln -c Release --no-restore -o CI_PROJECT_DIR/build/release',
      "dotnet sonarscanner end /d:sonar.login=$${PLUGIN_SONAR_TOKEN}"
    ]
  }
    
  docs = {
    "name": "generate_docs",
    "image": "hub.codefirst.iut.uca.fr/thomas.bellembois/codefirst-docdeployer",
    "failure": "ignore",
    "volumes": [
      {"name": "docs", "path": "/Documentation"}
    ],
    "commands": ["/entrypoint.sh"]
  }
  deploy_db = {
    "name": "deploy-container-mysql",
    "image": "hub.codefirst.iut.uca.fr/thomas.bellembois/codefirst-dockerproxy-clientdrone:latest",
    "environment": {
      "IMAGENAME": "mariadb:10",
      "CONTAINERNAME": "mysql",
      "COMMAND": "create",
      "OVERWRITE": "false",
      "PRIVATE": "true",
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_ROOT_PASSWORD": {"from_secret": "db_root_password"},
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_DATABASE": {"from_secret": "db_database"},
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_USER": {"from_secret": "db_user"},
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_PASSWORD": {"from_secret": "db_password"},
    }
  }
  docker_build_and_push = {
    "name": "docker-build-and-push",
    "image": "plugins/docker",
    "settings": {
      "dockerfile": "Sources/Dockerfile",
      "context": "Sources/",
      "registry": "hub.codefirst.iut.uca.fr",
      "repo": "hub.codefirst.iut.uca.fr/corentin.richard/cicd_3a_corentinrichard",
      "username": {"from_secret": "SECRET_REGISTRY_USERNAME"},
      "password": {"from_secret": "SECRET_REGISTRY_PASSWORD"}
    }
  }
  stub = {
    "name": "deploy-container-with-stub",
    "image": "hub.codefirst.iut.uca.fr/thomas.bellembois/codefirst-dockerproxy-clientdrone:latest",
    "environment": {
      "CODEFIRST_CLIENTDRONE_ENV_SWITCH_CSHARP": "stub",
      "IMAGENAME": "hub.codefirst.iut.uca.fr/corentin.richard/cicd_3a_corentinrichard:latest",
      "CONTAINERNAME": "csharp_stubbed",
      "COMMAND": "create",
      "OVERWRITE": "true"
    },
    "depends_on": ["docker-build-and-push"]
  }
  api = {
    "name": "deploy-container-with-API",
    "image": "hub.codefirst.iut.uca.fr/thomas.bellembois/codefirst-dockerproxy-clientdrone:latest",
    "environment": {
      "CODEFIRST_CLIENTDRONE_ENV_SWITCH_CSHARP": "api",
      "IMAGENAME": "hub.codefirst.iut.uca.fr/corentin.richard/cicd_3a_corentinrichard:latest",
      "CONTAINERNAME": "csharp_api",
      "COMMAND": "create",
      "OVERWRITE": "true"
    },
    "depends_on": ["docker-build-and-push"]
  }
  db = {
    "name": "deploy-container-with-DB",
    "image": "hub.codefirst.iut.uca.fr/thomas.bellembois/codefirst-dockerproxy-clientdrone:latest",
    "environment": {
      "CODEFIRST_CLIENTDRONE_ENV_SWITCH_CSHARP": "db",
      "IMAGENAME": "hub.codefirst.iut.uca.fr/corentin.richard/cicd_3a_corentinrichard:latest",
      "CONTAINERNAME": "csharp_db",
      "COMMAND": "create",
      "OVERWRITE": "true",
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_ROOT_PASSWORD": {"from_secret": "db_root_password"},
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_DATABASE": {"from_secret": "db_database"},
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_USER": {"from_secret": "db_user"},
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_PASSWORD": {"from_secret": "db_password"},
      "CODEFIRST_CLIENTDRONE_ENV_MARIADB_HOST": "corentinrichard-mysql",
    }
  }
   
  steps_to_execute = []
  if ctx.build.branch == "master":
    steps_to_execute.append(build)
    steps_to_execute.append(test)
    if ".drone.star" not in ctx.build.message:
      steps_to_execute.append(code_inspection)
      steps_to_execute.append(docs)
    steps_to_execute.append(docker_build_and_push)
    steps_to_execute.append(deploy_db)

    if "[database]" in ctx.build.message:
      steps_to_execute.append(db)
    elif "[wrapper]" in ctx.build.message:
      steps_to_execute.append(api)
    elif "[stub]" in ctx.build.message:
      steps_to_execute.append(stub)
    else:
      steps_to_execute.append(db)


  else:
    steps_to_execute.append(build)
    steps_to_execute.append(test)
    if "[sonar]" in ctx.build.message or "[ci_all]" in ctx.build.message:
      steps_to_execute.append(code_inspection)
    if "[doxygen]" in ctx.build.message or "[swagger]" in ctx.build.message:
      steps_to_execute.append(docs)
    if "[cd]" in ctx.build.message : 
      steps_to_execute.append(docker_build_and_push)
      steps_to_execute.append(deploy_db)
      if "[database]" in ctx.build.message:
        steps_to_execute.append(db)
      elif "[wrapper]" in ctx.build.message:
        steps_to_execute.append(api)
      elif "[stub]" in ctx.build.message:
        steps_to_execute.append(stub)
      else:
        steps_to_execute.append(db)
     

  if "[overwrite_db]" in ctx.build.message:
    deploy_db["environment"]["OVERWRITE"] = "true"
  
  if "README.md" in ctx.build.message or "[no_ci]" in ctx.build.message:
    steps_to_execute = []
  
  return {
    "kind": "pipeline",
    "type": "docker",
    "name": "sharpipeline",
    "steps": steps_to_execute
  }