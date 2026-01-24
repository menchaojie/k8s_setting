NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

echo "=== 节点网络状态检查 ==="
echo "节点名称: $NODE"
echo

echo "==网络条件===:"
kubectl describe node $NODE |grep -A 7 Conditions
echo

echo "=== 以上为节点 $NODE 的网络状态信息 ==="
# kubectl describe node $NODE 
