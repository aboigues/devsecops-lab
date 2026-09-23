// Équivalent Jenkins du pipeline GitLab CI (.gitlab-ci.yml) : mêmes contrôles, mêmes seuils.
// Prérequis : plugins Pipeline, Docker Pipeline, JUnit, Coverage ; agent avec Docker ;
// identifiants Jenkins « registry » (utilisateur/mot de passe) et « gitops-token » (texte secret).
pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        REGISTRY       = 'registry.example.org'
        IMAGE          = "${REGISTRY}/devsecops-lab/bank-api:${GIT_COMMIT.take(8)}"
        TRIVY          = 'aquasec/trivy:0.74.0'
        TRIVY_SEVERITY = 'HIGH,CRITICAL'
        TRIVY_IGNORE_UNFIXED = 'true'
    }

    stages {
        stage('Tests') {
            agent {
                docker {
                    image 'maven:3.9.16-eclipse-temurin-25'
                    args '-v maven-cache:/root/.m2'
                    reuseNode true
                }
            }
            steps {
                dir('app') { sh 'mvn -B verify' }
            }
            post {
                always {
                    junit 'app/target/surefire-reports/*.xml, app/target/failsafe-reports/*.xml'
                    recordCoverage tools: [[parser: 'JACOCO', pattern: 'app/target/site/jacoco/jacoco.xml']]
                }
            }
        }

        // Les analyses indépendantes tournent en parallèle : feedback rapide au développeur
        stage('Analyse') {
            parallel {
                stage('Secrets') {
                    steps {
                        sh 'docker run --rm -v "$WORKSPACE:/repo" zricethezav/gitleaks:v8.30.1 git /repo --redact --exit-code 1'
                    }
                }
                stage('SAST') {
                    steps {
                        sh 'docker run --rm -v "$WORKSPACE:/src" semgrep/semgrep:1.177.0 semgrep scan --config p/java --error /src/app'
                    }
                }
                stage('SCA + SBOM') {
                    steps {
                        sh 'docker run --rm -v "$WORKSPACE:/w" -w /w -e TRIVY_SEVERITY -e TRIVY_IGNORE_UNFIXED $TRIVY fs --scanners vuln --exit-code 1 app/'
                        sh 'docker run --rm -v "$WORKSPACE:/w" -w /w $TRIVY fs --format cyclonedx --output sbom.cdx.json app/'
                        archiveArtifacts 'sbom.cdx.json'
                    }
                }
                stage('IaC') {
                    steps {
                        sh 'docker run --rm -v "$WORKSPACE:/w" -w /w $TRIVY config --exit-code 1 --severity MEDIUM,HIGH,CRITICAL terraform/'
                    }
                }
            }
        }

        stage('Image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'registry', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    sh '''
                        echo "$REG_PASS" | docker login -u "$REG_USER" --password-stdin "$REGISTRY"
                        docker build -t "$IMAGE" app/
                        docker push "$IMAGE"
                    '''
                }
            }
        }

        stage('Scan image') {
            steps {
                sh 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -e TRIVY_SEVERITY -e TRIVY_IGNORE_UNFIXED $TRIVY image --exit-code 1 "$IMAGE"'
            }
        }

        stage('DAST') {
            steps {
                sh '''
                    docker network create dast-$BUILD_NUMBER
                    docker run -d --name app-$BUILD_NUMBER --network dast-$BUILD_NUMBER "$IMAGE"
                    docker run --rm --network dast-$BUILD_NUMBER -v "$WORKSPACE:/zap/wrk" zaproxy/zap-stable:2.17.0 \
                      bash -c "until curl -fsS http://app-$BUILD_NUMBER:8080/actuator/health/readiness; do sleep 3; done; \
                               zap-baseline.py -t http://app-$BUILD_NUMBER:8080/api/accounts -r zap-report.html"
                '''
            }
            post {
                always {
                    sh 'docker rm -f app-$BUILD_NUMBER || true; docker network rm dast-$BUILD_NUMBER || true'
                    archiveArtifacts artifacts: 'zap-report.html', allowEmptyArchive: true
                }
            }
        }

        stage('GitOps') {
            when { branch 'main' }
            steps {
                withCredentials([string(credentialsId: 'gitops-token', variable: 'GITOPS_TOKEN')]) {
                    sh '''
                        docker run --rm -v "$WORKSPACE:/w" -w /w mikefarah/yq:4.53.6 -i \
                          ".images[0].newName = \\"${IMAGE%:*}\\" | .images[0].newTag = \\"${IMAGE##*:}\\"" gitops/overlays/lab/kustomization.yaml
                        git -c user.name=gitops-bot -c user.email=gitops-bot@noreply.invalid \
                          commit -am "chore(gitops): bank-api ${IMAGE##*:} [skip ci]"
                        git push "https://gitops-bot:${GITOPS_TOKEN}@${GIT_URL#https://}" HEAD:main
                    '''
                }
            }
        }
    }
}
