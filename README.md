# K3s Agent Node - Docker Compose

Docker-based k3s agent node for connecting to an existing k3s cluster.

## Security Warning

This setup requires privileged container mode and significantly relaxed security constraints. Running k3s agents in Docker for production comes with inherent risks:

- Containers run with `--privileged` flag
- Host namespaces are accessible
- AppArmor and seccomp protections are disabled
- Container breakout risk is higher than normal

**Ensure you understand these implications before deploying to production.**

## Prerequisites

- Docker Engine 20.10+ with docker-compose
- Existing k3s cluster with accessible server
- k3s server token (node-token)
- Network connectivity from Docker host to k3s server

## Quick Start

### 1. Get Your K3s Server Token

On your k3s server, retrieve the node token:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

### 2. Configure Environment

Copy the example environment file and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```bash
# Required
K3S_URL=https://your-k3s-server:6443
K3S_TOKEN=K10abcdef...your-actual-token
NODE_NAME=k3s-agent-prod-1
```

### 3. Build and Start

```bash
# Build the image
docker-compose build

# Start the agent node
docker-compose up -d

# View logs
docker-compose logs -f
```

### 4. Verify Node Joined

On your k3s server, verify the node has joined:

```bash
kubectl get nodes
```

You should see your agent node listed.

## Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `K3S_URL` | URL of k3s server including port | `https://192.168.1.10:6443` |
| `K3S_TOKEN` | Node token from k3s server | `K10abc...` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_NAME` | Unique identifier for this node | `k3s-agent-node1` |
| `NODE_LABELS` | Node labels (comma-separated) | None |
| `K3S_DISABLE` | Components to disable | None |

### Node Labels Example

To add labels for workload scheduling:

```bash
NODE_LABELS=environment=production,region=us-west,type=compute
```

These labels can be used in pod specs for node affinity/selection.

## Volume Management

The compose file creates two persistent volumes:

- `k3s-agent-data`: K3s agent state and configuration
- `k3s-kubelet-data`: Kubelet data and pod information

### Backing Up Volumes

```bash
# List volumes
docker volume ls | grep k3s

# Backup a volume
docker run --rm -v k3s-node-docker-compose_k3s-agent-data:/data -v $(pwd):/backup alpine tar czf /backup/k3s-agent-backup.tar.gz /data
```

### Cleaning Up Volumes

```bash
# Stop and remove containers
docker-compose down

# Remove volumes (WARNING: Data loss)
docker-compose down -v
```

## Resource Limits

Uncomment and adjust the resource limits in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
    reservations:
      cpus: '2'
      memory: 4G
```

## Networking Considerations

### Network Mode

The default configuration uses bridge networking. Depending on your use case, you might need:

- **Host network**: Better performance, less isolation
  ```yaml
  network_mode: host
  ```

- **Custom network**: For multi-agent setups
  ```yaml
  networks:
    k3s-cluster:
      driver: bridge
  ```

### Firewall Requirements

Ensure these ports are accessible from the agent to the server:

- **6443**: K3s API server
- **10250**: Kubelet metrics (if using monitoring)

## Troubleshooting

### Agent Not Joining Cluster

**Check logs:**
```bash
docker-compose logs k3s-agent
```

**Common issues:**

1. **Invalid token**: Verify token matches server's node-token
2. **Network connectivity**: Test with `curl -k https://your-server:6443`
3. **Certificate issues**: Ensure server URL is correct (IP vs hostname)

### Container Keeps Restarting

```bash
# Check detailed container status
docker ps -a

# Inspect container
docker inspect k3s-agent-node1

# Check system logs
journalctl -u docker -f
```

### Node Shows as NotReady

The node might take 30-60 seconds to become ready. Check:

```bash
# On k3s server
kubectl describe node <node-name>

# Check events
kubectl get events --all-namespaces | grep <node-name>
```

### High Resource Usage

K3s agents consume resources based on workload. Monitor:

```bash
# Container stats
docker stats k3s-agent-node1

# Kubernetes resource usage
kubectl top node <node-name>
```

## Scaling Multiple Agents

To run multiple agent nodes on the same Docker host:

1. Create separate docker-compose files or use compose profiles
2. Ensure unique `NODE_NAME` for each agent
3. Consider resource limits to prevent overcommitment

Example multi-agent setup:

```bash
# Agent 1
NODE_NAME=k3s-agent-1 docker-compose -p agent1 up -d

# Agent 2
NODE_NAME=k3s-agent-2 docker-compose -p agent2 up -d
```

## Monitoring

### Health Checks

The Dockerfile includes a health check that queries k3s health endpoint:

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' k3s-agent-node1
```

### Log Management

Logs are configured with rotation (100MB max, 5 files):

```bash
# View logs
docker-compose logs -f

# Export logs
docker-compose logs > k3s-agent.log
```

## Maintenance

### Updating K3s Version

1. Update the version in `Dockerfile`:
   ```dockerfile
   FROM rancher/k3s:v1.31.3-k3s1
   ```

2. Rebuild and recreate:
   ```bash
   docker-compose build
   docker-compose up -d
   ```

### Graceful Shutdown

```bash
# Stop agent gracefully (allows pod draining)
docker-compose stop

# Remove completely
docker-compose down
```

### Removing Node from Cluster

Before removing the container, drain the node:

```bash
# On k3s server
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <node-name>
```

## Production Checklist

- [ ] Use Docker secrets or external secret management instead of .env files
- [ ] Implement proper log aggregation (ELK, Loki, etc.)
- [ ] Set up monitoring (Prometheus metrics on port 10250)
- [ ] Configure resource limits based on expected workload
- [ ] Use specific k3s version tags (not `latest`)
- [ ] Implement automated backup strategy for volumes
- [ ] Test disaster recovery procedures
- [ ] Document network security rules
- [ ] Regular security scanning of images
- [ ] Automated certificate rotation strategy

## Known Limitations

1. **Nested containerization**: Pods running on this agent are containers within containers
2. **Performance overhead**: Additional layer impacts performance vs bare metal
3. **Storage limitations**: Volume performance dependent on Docker storage driver
4. **Networking complexity**: CNI conflicts possible with Docker networking
5. **Signal handling**: Container restart doesn't gracefully drain pods

## Alternative Approaches

Consider these alternatives for production:

- **Bare metal**: Install k3s directly on VMs/physical servers
- **K3d**: Purpose-built tool for k3s in Docker (better for dev/test)
- **Managed Kubernetes**: Cloud provider solutions (EKS, GKE, AKS)
- **VM-based**: Run k3s in full VMs instead of containers

## Support

For k3s-specific issues, see: https://docs.k3s.io/
For Docker issues, see: https://docs.docker.com/

## License

This project is provided as-is without warranty. Use at your own risk.
