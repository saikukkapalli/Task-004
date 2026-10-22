 Kubernetes Monitoring and Failure Recovery 
                       

                   Technology Stack 
Docker | Nginx | Kubernetes | Minikube | Kubectl
Helm | Prometheus | Graphana Alloy |Loki | 


Overview :
 This Task is used to understand the centralized logging and visualization of the logs metrics. To Understand and troubleshoot if any issues occurs. we containerized a static website to Kubernetes using Minikube and by using the Prometheus and Grafana we are collecting metrics  where logs are collected using the Grafana Alloy. The logs are stored in the PV of the Loki. Also created dashboards for CPU usage, container restarts, and Nginx HTTP errors.

Demonstrated Kubernetes self healing by deleting  a pod and observing its replacement Tested the container recovery by stopping Nginx inside the container and observed the restart of the container 

Note: Alerting is not included in this version 

Architecture:
Metrics pipeline:
         Kubernetes/kube-state-metrics
                                ↓
               Prometheus
                                ↓
                  Grafana
Prometheus scrapes metrics from the Kubernetes monitoring stack. Grafana queries Prometheus to display metrics and pod status.

Logs Pipeline:
      Nginx Container Logs
             ↓
     Grafana Alloy
           ↓
            Loki
                  ↓
       Grafana
Nginx is configured to write access logs to stdout and error logs to stderr. Alloy discovers pods in the monitoring-lab namespace, collects their logs and forwards them to loki. Grafana queries Loki to explore the logs






Technology Stack
 Kubernetes: Minikube
 Container runtime / image tooling: Docker
  Web server: Nginx
  Metrics collection: Prometheus
  Kubernetes object metrics: kube-state-metrics
  Node metrics: node-exporter
  Log collection: Grafana Alloy
  Log storage and querying: Loki
  Visualization: Grafana
  Package management: Helm
  Configuration: YAML, Nginx configuration, Dockerfile



Repository Structure:
 

Prerequisites:

Install and configure the following tools on your machine:
•	Docker
•	Minikube
•	kubectl
•	Helm

Confirm that they are available:
docker –version
minikube version
kubectl version –-client
helm version

Start Minikube and check the cluster:
minikube start
kubectl get nodes 
This code shows eventually Ready .

Setup and Deployment
1.	Build the Website image
Run these commands from the project root, where the Dockerfile is Located 

Docker build -t devops-monitoring-lab:1.0 . 
Check the image:
         docker images
     if Minikube can’t access the image built by your local Docker daemon, make the image available to Minikube using the method supported by your steup. For example, Minikube supports loading an image:

minikube image load devops-monitoring-lab:1.0
Make sure the image name is matches in the built and loaded 

2.	Deploy the sample application

Create the application namespace if not exists

Kubectl create namespace -n monitoring-lab

Apply the deployment manifest:

kubectl apply -f deployment.yml 

Check the deployment and pods:

Kubectl get deployments -n monitoring-lab
Kubectl get pods -n monitoring-lab

Wait for pod to become ready. The deployment used in this project is devops-monitoring-lab

3.	Open the website:
Forward the local port 8080 to port 80 on the deployment

kubectl port-forward deployment/devops-monitoring-lab 8080:80 -n monitoring-lab

keep the terminal open and visit:
http://localhost:8080

Stop the port-forward with ctrl+c when finished.

4.	Install or verify the monitoring stack

The Prometheus/Grafana stack was installed using the Prometheus-community/kube-prometheus-stack Helm chart and the custom values.yaml file.

Helm upgrade –install monitoring Prometheus-community/kube-prometheus-stack –namespace monitoring –create-namespace  --vallues.yaml



Check the resources:

kubectl get pods -n monitoring 
kubectl get services -n monitoring 
helm list -n monitoring

5.	Install Loki 
Loki was installed using the Grafana/loki Helm chart and a custom values file. Use the same chart version and values used in your working env 
helm upgrade –install loki Grafana/loki –namespace monitoring –values loki-values.yml

Check loki resources:
Kubectl get pods -n monitoring
Kubectl get services -n monitoring

6.	Install or Verify Grafana Alloy
Alloy is configured through alloy-values.yml to discover pods in the monitoring-lab namespace and forward their logs to Loki.

Helm upgrade –install alloy Grafana/alloy –namespace monitoring –values alloy-values.yml

Check Alloy:

Kubectl get pods -n monitoring
Kubectl logs -n monitoring -l app.kubernetes.io/name=alloy  --all-containers=true

Important: The commands above show the setup pattern. Before
reinstalling, verify the Helm release names, chart versions,
namespace, and values files used in your existing cluster. Avoid
installing a second release just to inspect the project.

Accessing Grafana 
Forward local port 3000 to the Grafana service:
Kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring 
Keep the terminal open and visit
http://localhost:3000

Configure Grafana Data Sources
Prometheus
Configure the Prometheus data source to use the in-cluster Prometheus service address appropriate to your Hellm release. The exact service name can be checked with 
kubectl get services -n monitoring

Loki
This project uses the Loki gateway service as its data source. The in-cluster URL is:
http://loki-gateway.monitoring.svc.cluster.local
The Alloy write configuration uses tenant ID 1, so the Grafana data source must use a matching tenant configuration.
Useful Queries 
Use these queries in Grafana. Ensure the dashboard’s namespace variable is set to monitoring-lab when inspecting the same application.



CPU usage by pod (PromQL)
Sum by (pod) (
      Rate(container_cpu_usage_seconds_total{namespace=”monitoring-lab”}[5m])
)

Memory working set by pod (PromQL)
Sum by (pod) (
      container_memory_working_set_bytes{
            namespace=”monitoring-lab”,
        }
)

Container restarts by pod (PromQL)
Sum by (pod) (
       Kube_pod_container_status_restarts_total{
             namespace=”monitoring-lab”
            }
)
This metric can return a series for each phase. The current phase is represented by the series with the value 1 other phase series normally have 0 value 
Application logs (LogQL)
{job=”loki.source.kubernetes.pods”}

Nginx 404 logs (LogQL)
{job=”loki.source.kubernetes.pods”} | “404”

The log selector depends on the tables Alloy attaches to logs. If a query returns no results, inspect the Grafana and adapt the label selector according to your data.

Failure-Recovery Tests
These tests demonstrate basic k8s recovery behavior. Perform them only locally 

Test 1: Delete the application pod

Kubectl get pods -n monitoring-lab
Kubectl delete pod <pod-name> -n monitoring-lab
Observe the deployment and pods:
Kubectl get pods -n monitoring-lab -w
Expected result:
Because the pod is managed by a Deployment/ReplicaSet, k8s should create a replacement pod to maintain the desired replica count.

Test 2 : Stop Nginx inside the application container
Kubectl get pods -n monitoring-lab
Kubectl exec <pod-name> -n monitoring-lab – nginx -5 quit
Then inspect the pod and restart count:
Kubectl get pods -n monitoring-lab
Kubectl describe pod <pod-name> -n monitoring-lab
Expected result in the tested setup: The container restarted and its
restart count increased. Depending on the pod and container lifecycle,
the pod name can remain the same when a container restarts. This is
different from deleting a pod, which causes a replacement pod to be
created.
Troubleshooting
Pod is not ready
Kubectl get pods -n monitoring-lab
Kubectl describe pod <pod-name> -n monitoring-lab
Kubectl logs  <pod_name> -n monitoring-lab

Website is not accessible
Confirm the application pod is ready, then run the port-forward command
again:
kubectl port-forward deployment/devops-monitoring-lab 8080:80 -n monitoring-lab
Make sure port 8080 is not already in use.

No logs appear in Loki
Check that:
1.	The application pod is in the monitoring-lab namespace.
2.	Alloy is running in the monitoring namespace.
3.	The Alloy configuration discovers monitoring-lab pods.
4.	The Loki endpoint and tenant ID in Alloy match the Loki
installation.
5.	The Grafana Loki data source uses the correct URL and tenant header.
6.	The selected time range in Grafana includes the log events.
Useful checks:
kubectl get pods -n monitoring
kubectl logs <alloy-pod-name> -n monitoring --all-containers=true
kubectl get services -n monitoring

No metrics appear in Grafana
Check Prometheus and the monitoring pods:
kubectl get pods -n monitoring
kubectl get services -n monitoring
Verify that the Prometheus data source is configured correctly and that
the dashboard's namespace variable is set to monitoring-lab.

Learning Outcomes
By completing this project, you practice:
•	Building and running a Docker image for a static website.
•	Deploying applications to Kubernetes.
•	Using namespaces, Deployments, ReplicaSets, pods, and port
forwarding.
•	Installing Kubernetes monitoring tools with Helm.
•	Querying CPU, memory, pod phase, and restart metrics with PromQL.
•	Collecting container logs with Grafana Alloy and querying them with
LogQL in Loki.
•	Building Grafana dashboards for monitoring.
•	Demonstrating pod replacement and container restart behavior.
•	Troubleshooting Kubernetes resources and observability pipelines.

Future Improvements
Possible extensions include:
•	Add alerting rules and notification channels.
•	Add dashboard provisioning so dashboards can be recreated
automatically.
•	Pin container images and Helm chart versions for reproducible
deployments.
•	Add persistent storage for Grafana if dashboard state needs to
survive pod replacement.
•	Add CI to validate Kubernetes YAML and build the Docker image.
•	Add a documented cleanup procedure for local lab resources.

Cleanup
Review resources before deleting anything. To remove the sample
application:
kubectl delete -f deployment.yml
To stop Minikube when you are finished with the lab:
minikube stop
Only uninstall Helm releases or delete namespaces after confirming which
resources belong to this project.





