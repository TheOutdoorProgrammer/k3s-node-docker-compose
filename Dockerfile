FROM rancher/k3s:v1.33.5-k3s1

# Note: The rancher/k3s image is minimal by design and doesn't include package managers.
# Additional utilities would require a multi-stage build, but k3s includes what it needs.

# Create necessary directories
RUN mkdir -p /var/lib/rancher/k3s/agent \
    && mkdir -p /var/lib/kubelet \
    && mkdir -p /etc/rancher/k3s

# Set up proper permissions
RUN chmod 755 /var/lib/rancher/k3s/agent \
    && chmod 755 /var/lib/kubelet

# Volume for persistent data
VOLUME ["/var/lib/rancher/k3s", "/var/lib/kubelet"]

# Expose kubelet metrics port (optional, useful for monitoring)
EXPOSE 10250

# Health check to ensure k3s agent is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD k3s kubectl get --raw /healthz 2>/dev/null || exit 1

# Run k3s in agent mode
# Using exec form to ensure proper signal handling for graceful shutdown
ENTRYPOINT ["/bin/k3s"]
CMD ["agent"]
