# Local Workflow

这个仓库现在按“官方库 + 个人学习内容”的方式使用。

## 你的个人内容放哪里

优先放在这些目录：

- `my_work/`
- `MayDay_ADCToolbox_Study/`
- `adc_plotspec/`

这些目录已经加入 `.gitattributes` 的合并保护规则。如果 upstream 以后碰巧新增了同名路径，合并时会优先保留你本地的版本。

## 每次写完自己的内容

先提交你的内容：

```powershell
git status
git add .
git commit -m "Update my study notes"
```

提交之后再同步官方库，这样就算发生冲突，也可以从 Git 历史里找回你的内容。

## 同步官方库

推荐用脚本：

```powershell
.\scripts\sync-upstream.ps1
```

脚本会做这些事：

1. 检查当前目录是不是 Git 仓库。
2. 检查有没有未提交改动；如果有，会停下来让你先提交。
3. 确认 `upstream` 指向 `https://github.com/Arcadia-1/ADCToolbox.git`。
4. 拉取 `upstream/main`。
5. 合并到当前分支。

如果你改了官方源码里的同一个文件，Git 可能会提示冲突。这个时候不要强行 reset，先打开冲突文件，把你的修改和 upstream 修改合在一起，然后：

```powershell
git add .
git commit
```

## 推送到你自己的 GitHub

同步成功后：

```powershell
git push origin main
```

