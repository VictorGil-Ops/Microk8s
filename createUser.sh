#!/usr/bin/env bash

# Ref: https://github.com/k3s-io/k3s/issues/684
# Ref: https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
# Ref: https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
# Ref: https://tldp.org/LDP/abs/html/here-docs.html
# Ref: https://linuxize.com/post/bash-check-if-file-exists/

log () {

    NOCOLOR='\033[0m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    RED='\033[1;31m'
    PURPLE='\033[0;35m'

    case $2 in
        0 | INFO)
            COLOR=$GREEN
            LEVEL="INFO"
            ;;
        1 | WARN)
            COLOR=$YELLOW
            LEVEL="WARN"
            ;;
        2 | FAIL | ERROR )
            COLOR=$RED
            LEVEL="FAIL"
            ;;
        * ) # When $2 it's not one of the above
            COLOR=$PURPLE
            LEVEL="\?\?\?\?"
            ;;
    esac

    # If no argument is passed we mean it's ok
    if [[ -z "$2" ]];
    then
        COLOR=$GREEN
        LEVEL="INFO"
    fi

    if [ -z "$workdir" ]; then workdir="."; fi

    printf "$(date)$COLOR [$LEVEL]$NOCOLOR $1\n" | tee -a $workdir/log.log

}

setup_environment() {
    workdir=$(mktemp -d --suffix -microk8s)
    
    mkdir -p $workdir/{ca,keys,kube} 
    log "... created $workdir/{ca,keys,kube} subfolders"

    user="$1"
    group="CloudOps"

    cluster_name="microk8s-cluster"
    cluster_url="https://127.0.0.1:16443"
    cluster_ns="$2"

    days_until_expiration="$3"

    context="$4"

    log "... working directory      = $workdir"
    log "... user                   = $1"
    log "... group                  = $group"
    log "... cluster_name           = $cluster_name"
    log "... cluster_url            = $cluster_url"
    log "... cluster_ns             = $cluster_ns"
    log "... days_until_expiration  = $days_until_expiration"
    log "... context                = $context\n"
}

copy_ca_certs() {
    msg="Copying MicroK8s certs to $workdir/ca\n"
    cp /var/snap/microk8s/current/certs/* $workdir/ca
    if [ $? -eq 0 ]; then log "${msg}"; else log "${msg}" FAIL; exit 1;  fi
}


generate_key_and_csr() {
    log "... generating \"keys/$user.key\""
    openssl genrsa -out $workdir/keys/$user.key 2048
    # openssl ecparam -name prime256v1 -genkey -noout -out $user.key
    log "... creating certificate signing request"
    openssl req -new -key $workdir/keys/$user.key -out $workdir/keys/$user.csr -subj "/CN=${user}/O=${group}"
    log "... signing the CSR\n"
    openssl x509 -req -in $workdir/keys/$user.csr -out $workdir/keys/$user.crt \
      -CA $workdir/ca/client-ca.crt -CAkey $workdir/ca/client-ca.key \
      -CAcreateserial -days $days_until_expiration
}

generate_kubeconfig() {
    log "... kubeconfig's cluster name to $cluster_name ..."
    kubectl --kubeconfig=$workdir/kube/$user-kubeconfig config set-cluster $cluster_name \
      --server=$cluster_url --certificate-authority=$workdir/ca/server-ca.crt \
      --embed-certs=true
    log "... kubeconfig's user to $user ..."
    kubectl --kubeconfig=$workdir/kube/$user-kubeconfig config set-credentials $user \
      --client-certificate=$workdir/keys/$user.crt --client-key=$workdir/keys/$user.key \
      --embed-certs=true
    log "... context $context ..."
    kubectl --kubeconfig=$workdir/kube/$user-kubeconfig config set-context $context \
      --namespace=$cluster_ns --user=$user --cluster=$cluster_name
    log "... Kubeconfig file created $workdir/kube/$user-kubeconfig"
    if [ "$1" == "use-context" ]
    then
        log "... setting current context to \"$context\""
        kubectl config use-context $context --kubeconfig $workdir/kube/$user-kubeconfig
    fi
}

generate_cluster_role() {
    cat > $workdir/kube/clusterrole.yaml <<ROLEDEF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $cluster_ns
  name: CloudOps_role
rules:
- apiGroups: ['rbac.authorization.k8s.io'] # '' indicates the core API group
  resources: ['pods', 'configmaps', 'services', 'endpoints', 'crontabs', 'deployments', 'jobs', 'nodes']
  verbs: ["get", "post", "list", "watch", "create", "update", "patch", "delete"]
ROLEDEF

generate_cluster_role() {
    cat > $workdir/kube/clusterrole.yaml <<CLUSTERROLEDEF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  namespace: $cluster_ns
  name: CloudOps_clusterrole
rules:
- apiGroups: ['rbac.authorization.k8s.io'] # '' indicates the core API group
  resources: ['pods', 'configmaps', 'services', 'endpoints', 'crontabs', 'deployments', 'jobs', 'nodes']
  verbs: ["get", "post", "list", "watch", "create", "update", "patch", "delete"]
CLUSTERROLEDEF

log "... created CloupsOps \"All\" (CloudOps) role manifest for user \"$user\" at $workdir/kube/ "
}

generate_rolebinding() {
    cat > $workdir/kube/rolebinding.yaml <<ROLEBINDINGDEF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: $cluster_ns
  name: bind-CloudOps-role
subjects:
- kind: User
  name: $user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: CloudOps
  apiGroup: rbac.authorization.k8s.io
ROLEBINDINGDEF


log "... created RoleBinding manifest for User:\"$user\" and Role:\"CloudOps\" at $workdir/kube/ "
}

__check_kubeconfig(){
    if [[ ! -z "$1" ]]
    then
        log "Using custom kubeconfig file $1"
        KUBECONFIG_FILE="--kubeconfig $1"
    elif [[ ! -z "$KUBECONFIG" ]]
    then
        log "Using \"\$KUBECONFIG=$KUBECONFIG\" variable"
        KUBECONFIG_FILE=""
    elif [[ -f "$HOME/.kube/config" ]]
    then
        log "Using default kubeconfig at \"$HOME/.kube/config\""
        KUBECONFIG_FILE="--kubeconfig $HOME/.kube/config"
    else
        log "No \"kubeconfig\" configuration found or provided. Abort" ERROR
        exit 1
    fi
}

__check_current_context(){
    CURRENT_CONTEXT="$(kubectl config current-context $1)"
    if [[ -z "$CURRENT_CONTEXT" ]]
    then
        log "No current context defined" ERROR
        exit 1
    else
        if [[ ! -z "$KUBECONFIG" ]]
        then
            log "Current context \"$CURRENT_CONTEXT\" from \$KUBECONFIG=$KUBECONFIG"
        else
            log "Current context \"$CURRENT_CONTEXT\" in \"$1\""
        fi
    fi
}

__kubectl_apply(){
    result=$($1)
    if [[ "$result" ]]
    then
        log "\"kubectl apply\" SUCCEEDED: \"$result\""
    else
        log "\"kubectl apply\" FAILED :( \"$result\"" ERROR
        exit 1
    fi
}

bind_cluster_role_to_user() {
    custom_kubeconfig="$1" 
    __check_kubeconfig "$custom_kubeconfig"
    __check_current_context "$KUBECONFIG_FILE"

    kubectl_apply_role="kubectl apply -f $workdir/kube/role.yaml $KUBECONFIG_FILE"
    kubectl_apply_rolebinding="kubectl apply -f $workdir/kube/rolebinding.yaml $KUBECONFIG_FILE"

    __kubectl_apply "$kubectl_apply_role"
    __kubectl_apply "$kubectl_apply_rolebinding"
}

# SCRIPT STARTS HERE

# SETUP
# -----
echo "------------------------------------------------------------------------------"
log "Setting variables and temp dir ..."
# setup_environment  USERNAME NAMESPACE DAYSTOEXPIRE CONTEXT
setup_environment    "victor"   "default" 300           "microk8s"
copy_ca_certs

# Authentication
# --------------
echo "------------------------------------------------------------------------------"
log "Generating key and csr for $user ..."
generate_key_and_csr


# Authorization
# -------------
echo "------------------------------------------------------------------------------"
log "Generating Role manifest ..."
generate_cluster_role
log "Generating RoleBinding manifest ..."
generate_rolebinding

echo "------------------------------------------------------------------------------"
# bind_sample_role_to_user KUBECONFIG file [OPTIONAL]  
bind_cluster_role_to_user "/home/victor/.kube/config"

# Test new user
# -------------
echo "------------------------------------------------------------------------------"
log "Generating \"kubeconfig\" file for user $user ..."
generate_kubeconfig "use-context"

echo "------------------------------------------------------------------------------"
echo "Test the new user \"$user\" running:"
echo "  kubectl get pods --namespace $cluster_ns --kubeconfig=$workdir/kube/$user-config"


# AUX function
decode_cert() {
    log "$1"
    openssl x509 -in "$1" -text -noout
}
# decode_cert "k3s/client-ca.crt"    # Public CA's certificate 
# decode_cert "xavi.crt"             # Client certificate signed by Kubernetes's CA
