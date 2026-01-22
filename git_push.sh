
echo ">>>>>>>>>>>>>>>>>>>>当前Git状态:"
git status

read -p ">>>>>>>>>>>>>>>>添加所有内容到暂存区(Enter-->yes):"
git add .
echo ">>>>>>>>>>>>>>>>>>>>当前Git状态:"
git status

read -p ">>>>>>>>>>>>>>>>将暂存区内容提交到本地仓库(Enter-->yes):"
read -p "请输入commit的tag:" COMMIT_TAG
git commit -m  "$COMMIT_TAG"
echo ">>>>>>>>>>>>>>>>>>>>当前Git状态:"
git status

read -p ">>>>>>>>>>>>>>>>提交本地仓库到到远程仓库(Enter-->yes):"
git push
echo ">>>>>>>>>>>>>>>>>>>>当前Git状态:"
git status
echo ">>>>>>>>>>>>>>>>>>>>当前Git log:"
git log
echo "===============本次操作结束===================="
