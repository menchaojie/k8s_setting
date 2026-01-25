sudo kubeadm join 100.64.0.4:6443 \
  --token m2b6qb.1bgohwmtbm1j4dbt \
  --discovery-token-ca-cert-hash sha256:bc9f34263f40f2ef532c468cdb3c900c965c2dfb1d056649f0245f602c941d0e \
  --cri-socket unix:///var/run/cri-dockerd.sock

