# zsh-config

在任意 Linux / macOS 服务器上一条命令装好 zsh 的配置。默认带 oh-my-zsh 和
starship；网络或权限不允许时会自动降级，最差情况也能得到一个可用的纯 zsh。

## 一键安装

```sh
curl -fsSL https://raw.githubusercontent.com/chao2hang/zsh-config/main/install.sh | bash
```

带参数时用 `bash -s --`：

```sh
# 只装纯 zsh，不依赖 oh-my-zsh / starship
curl -fsSL https://raw.githubusercontent.com/chao2hang/zsh-config/main/install.sh | bash -s -- --minimal
```

已经克隆了仓库，直接执行：

```sh
bash install.sh
```

## 安装脚本做了什么

1. 检测 `apt-get`、`dnf`、`yum`、`apk`、`pacman`、`zypper`，补装 `zsh git curl`；
2. `git clone --depth=1` 安装 oh-my-zsh（已存在则跳过）；
3. 安装 starship 到 `~/.local/bin`（root 则装到 `/usr/local/bin`）；
4. 备份旧 `~/.zshrc` 为 `~/.zshrc.bak.<时间戳>`，写入新配置；
5. 把 zsh 写进 `/etc/shells` 并执行 `chsh`。

脚本是幂等的：重复执行只会覆盖配置，旧文件照样备份。

## 选项

| 选项 | 作用 |
| --- | --- |
| `--minimal` | 跳过 oh-my-zsh 和 starship，只用纯 zsh |
| `--no-omz` | 跳过 oh-my-zsh |
| `--no-starship` | 跳过 starship |
| `--no-chsh` | 不修改登录 shell |
| `-y`, `--yes` | 安装系统包时不再询问 |

非交互执行（管道、CI）会自动跳过询问。另外支持两个环境变量：
`ZSH_CONFIG_REPO`（默认 `chao2hang/zsh-config`）和 `ZSH_CONFIG_BRANCH`
（默认 `main`），用于私有镜像或分支。

## 三种运行结果

| 环境 | 行为 |
| --- | --- |
| oh-my-zsh + starship | starship 提示符、git 别名、补全、自动建议、语法高亮 |
| 只有 zsh | 内置 `compinit` 补全和双色提示符，无外部依赖 |
| 网络受限 | oh-my-zsh / starship 安装失败只告警，自动降级 |

## 手动安装

```sh
cp zshrc ~/.zshrc
exec zsh
```

`zshrc` 不包含任何硬编码用户名或绝对家目录，也可以只拷这一个文件。

## 字体与 locale

提示符图标由**你连接服务器所用的本地终端**渲染，所以 Nerd Font（如
MesloLGS NF、JetBrainsMono Nerd Font）只需要装在本地，服务器不用装。
服务器端把 locale 设为 UTF-8 即可；`LANG=C` 时图标会显示异常。

## 回滚

```sh
mv ~/.zshrc.bak.<时间戳> ~/.zshrc && exec zsh
```

## 配置文件说明

- `HISTSIZE` / `SAVEHIST` 各 5 万条，多终端共享历史；
- 只在目录存在时才把 `~/bin`、`~/.local/bin`、`~/.cargo/bin`、`~/go/bin` 加入 PATH；
- 关闭 oh-my-zsh 自动更新提示，适合共享服务器；
- 可用 `ZSH_NO_OMZ=1`、`ZSH_NO_STARSHIP=1` 临时关闭对应组件。

## 目录结构

```
zsh-config/
├── install.sh   # 安装脚本（可独立运行）
├── zshrc        # 安装为 ~/.zshrc
├── README.md
├── LICENSE
└── .gitignore
```
