bash stop-containers.sh

# Delete all items from docker to get a fresh start
echo "Removing all docker images and containers ..."
docker system prune -a -f

# Delete all volumes to get a fresh start
echo "Removing all docker volumes ..."
docker volume prune -a -f

# Delete all gitea data
echo "Deleting all gitea data ..."
sudo rm -rf gitea/gitea

# Delete kind
echo "Deleting KInD"
#sudo rm -rf ./kind
sudo rm -rf /usr/local/bin/kind