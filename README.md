# CAS_Exporter
Exports Open CAS Linux statistics to Prometheus for inclusion in Grafana dashboards

Open CAS Linux is available here: https://github.com/Open-CAS/open-cas-linux

## Example
The following image is from a Grafana dashboard showing the OCF Exporter tool data being graphed via Prometheus
![alt text](spdk_parser_sample_image.jpg "Example")

## Usage
cas_exporter [-port=PORT_NUMBER] | [-cache=INSTANCE_NUMBER] |  
            [-log] | [-logfile=FULL_PATH_TO_LOG]  |  
            [-sleep=SECS_TO_SLEEP_BETWEEN_ITERATIONS] 
            

| Option   |        Argument       |  Description |
|----------|:---------------------:|--------------|
| -port    | PORT_NUMBER           | The TCP port number spdk_parser will bind to in order to publish metrics  |
| -cache   | INSTANCE_NUMBER       |   The number of the cache instance to get statistics for |
| -log     |                       | Enable logging     |
| -logfile | FULL_PATH_TO_LOG      |    The path to the log file where output will be sent to when log is enabled  |
| -sleep   | SECS_TO_SLEEP         |    The number of seconds to sleep between iterations of metric gathering  |


## Instructions
This tool is written in Go and has been tested with Red Hat Linux 7.5  
Open CAS Linux should be installed and configured. If not, follow instructions available here: https://open-cas.github.io/getting_started_open_cas_linux.html


To use follow these general instructions:  
1. First install Prometheus  
>```wget https://github.com/prometheus/prometheus/releases/download/v2.10.0/prometheus-2.10.0.linux-amd64.tar.gz```  

>```tar xvzf prometheus-2.10.0.linux-amd64.tar.gz```  
>```cd prometheus-2.10.0.linux-amd64```  

2. Determine what port to use for the CAS Exporter (default is 2114).  Edit the *prometheus.yml* file and add this port as a target ('localhost:2114' for example)
>```vi prometheus.yml```  
  
>> static_configs:
>>            - targets: ['localhost:9090', 'localhost:2114']

3. Start Prometheus  
>``` ./prometheus & ```  

4. If you do not have the Go environment get it with:  
> ```https://golang.org/dl/```  
> ```tar -C /usr/local -xzf go$VERSION.$OS-$ARCH.tar.gz```  
> ```export PATH=$PATH:/usr/local/go/bin```  

5. Install the Prometheus API for Go  
>``` go get github.com/prometheus/client_golang/prometheus```  
>```go get github.com/prometheus/client_golang/prometheus/promauto```  
>```go get github.com/prometheus/client_golang/prometheus/promhttp```  

6. Clone CAS Exporter
> ```mkdir -p /root/go/src```  
> ```cd /root/go/src```  
> ```git clone https://github.com/felipe-barajas/CAS_Exporter ```

7. Compile CAS Exporter  
> ``` cd CAS_Exporter ```  
> ``` go build cas_exporter.go ```  
  
8. Run CAS Exporter using the port defined above (2114), getting CAS stats for cache instance *1*, logging data to /tmp/spdk_parser.out and sleeping 1 sec between metric recordings
> ``` ./cas_exporter -port=2114 -cache=1 -log -logfile="/tmp/spdk_parser.out" -sleep=1 ```  

9. On the Grafana server setup the newly created Prometheus source. The default port for the Prometheus server is 9090. For example:  
![alt text](spdk_parser_datasource_image.jpg "Example")

10. On the Grafana server create a dashboard and add a panel. The panel needs to point to the Prometheus data source created in the step above.  The metric query to use is one defined by CAS Exporter. See the next section for all the options.  For example, to see the instantaneous rate of the Reads from the CAS, use a metric query as shown in the picture below  
![alt text](spdk_parser_dashboard_image.jpg "Example")

Alternatively, under the Metrics drop down menu, select the "ocf" section as shown below.
![alt text](spdk_parser_metrics_image.jpg "Example")
  
All the available metrics exposed by this tool will appear here. A sample dashboard is also provided in the *sample_dashboard.json* file. This file can be manaully edited and imported into Grafana as well.

### CAS Exporter Queries Supported
The CAS metrics can be filtered using category and subcategory  
For example: ocf_percentage{category="requests", subcategory="rd_hits"}  

- Metric: ocf_count  
Description: OCF count value

- Metric: ocf_percentage  
Description: OCF percentage value 

For the two OCF metrics above, the supported categories are: 
- usage
- requests
- blocks 
- errors

The subcagetories for usage are: 
- occupancy  
- free   
- clean   
- dirty  

The subcategories for requests are: 
- rd_hits 
- rd_partial_misses
- rd_full_misses
- rd_total
- wr_hits
- wr_partial_misses
- wr_full_misses
- wr_total
- rd_pt
- wr_pt
- serviced 
- total.  

The subcategories for blocks and errors are: 
- core_volume_rd 
- core_volume_wr 
- core_volume_total 
- cache_volume_rd 
- cache_volume_wr 
- cache_volume_total 
- volume_rd 
- volume_wr 
- volume_total  
