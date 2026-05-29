echo "Stopping all containers"
docker stop $(docker ps -q)