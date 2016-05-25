IP := $(shell docker-machine ip default)

run:
	docker-compose stop
	docker-compose build
	docker-compose up -d
	@echo "Waiting for Kibana"
	@while true; do curl --silent http://$(IP):5601 >/dev/null && break; sleep 2; done
	@echo "Loading initial input from logs/initial-input.log"
	@sleep 10
	nc $(IP) 5000 < logs/initial-input.log 
	open http://$(IP):5601

stop:
	docker-compose stop