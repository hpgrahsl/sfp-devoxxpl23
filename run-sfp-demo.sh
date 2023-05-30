#!/bin/sh

echo "SETUP: deploying kafka and kafka connect ..."

kubectl apply -f kubernetes/kafka.yaml
kubectl apply -f kubernetes/connect.yaml

echo "SETUP: deploying databases (mysql and mongodb) ..."

kubectl apply -f kubernetes/mysql.yaml
kubectl apply -f kubernetes/mongodb.yaml

echo "SETUP: deploying applications (monolith and microservice) ..."

kubectl apply -f kubernetes/petclinic-monolith.yaml
kubectl apply -f kubernetes/owner-service.yaml

echo "SETUP: deploying proxy ..."

kubectl apply -f kubernetes/nginx.yaml

read -p "DEMO STEP 1: register MySQL source connector for owners table"

kubectl apply -f kubernetes/create-connector-mysql-source.yaml

read -p "inspect owners data in kafka originating from monolith's mysql"

kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.33.0-kafka-3.3.2 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic mysql1.petclinic.owners --from-beginning

read -p "DEMO STEP 2: register MongoDB sink connector for owners topic"

kubectl apply -f kubernetes/create-connector-mongodb-sink.yaml

read -p "inspect owners data in mongodb collection backing the microservice"

kubectl run mongo-query -ti --image=quay.io/hgrahsl/mongo:6.0.5 --rm=true --restart=Never -- mongosh mongodb:27017 --eval "use petclinic" --eval "db.getCollection('mysql1.petclinic.owners').find()"

read -p "DEMO STEP 3: change proxy config to route owner reads to microservice"

kubectl patch deployment nginx --patch-file kubernetes/patch-nginx-ms-read.yaml

read -p "DEMO STEP 4: change proxy config to route owner writes to microservice"

kubectl patch deployment nginx --patch-file kubernetes/patch-nginx-ms-read-write.yaml

read -p "DEMO STEP 5: unregister MySQL source connector & MongoDB sink to ignore owner table changes"

kubectl apply -f kubernetes/delete-connector-mysql-source.yaml
kubectl apply -f kubernetes/delete-connector-mongodb-sink.yaml

read -p "DEMO STEP 6: register MongoDB source and MySQL sink connector for owners collection"

kubectl apply -f kubernetes/create-connector-mongodb-source.yaml
kubectl apply -f kubernetes/create-connector-mysql-sink.yaml

read -p "inspect owners data in kafka originating from microservice's mongodb"

kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:0.33.0-kafka-3.3.2 --rm=true --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic mongodb.petclinic.mysql1.petclinic.owners --from-beginning

read -p "Done :-)"
