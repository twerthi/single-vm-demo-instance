echo "Starting all containers"
docker start $(docker ps -a -q)