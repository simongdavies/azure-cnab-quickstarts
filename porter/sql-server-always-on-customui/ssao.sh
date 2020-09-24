
function wait-for-sql-custom-resource {
    crd=''
    while [[ -z $crd ]]
        do crd=$(kubectl get crd --field-selector=metadata.name=sqlservers.mssql.microsoft.com --ignore-not-found=true)
        echo 'Waiting for sql server CRD to be created'
        sleep 30
    done
}

function output-primary-ip-address {
    PRIMARY_IP=''
    KUBE_NAMESPACE=$1
    AVAILABILITY_GROUP_NAME=$2
    while [[ -z $PRIMARY_IP ]]
        do PRIMARY_IP=$(kubectl get svc/$AVAILABILITY_GROUP_NAME-primary -n $KUBE_NAMESPACE -o=jsonpath='{.status.loadBalancer.ingress[0].ip}' --ignore-not-found=true)
        echo 'Waiting for primary AG IP Address' 
        sleep 30
    done
    echo ${PRIMARY_IP} > /tmp/ipaddress
}


function replace-tokens {
    export KUBE_NAMESPACE=$1
    export AVAILABILITY_GROUP_NAME=$2
    
    envsubst < /cnab/app/manifests/ag-services-template.yaml > /cnab/app/manifests/ag-services.yaml
    envsubst < /cnab/app/manifests/sql-operator-template.yaml > /cnab/app/manifests/sql-operator.yaml
    envsubst < /cnab/app/manifests/sql-server-template.yaml > /cnab/app/manifests/sql-server.yaml
}

function create-namespace {
    kubectl create namespace $1
}

"$@"