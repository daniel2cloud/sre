# Terraform 零停机部署示例

此文件夹包含在AWS（Amazon Web Services）上使用[Terraform](https://www.terraform.io/)进行零停机部署的示例。

它展示了当你对代码进行更改时，如何在集群中部署新的AMI。此外，你还可以控制用户数据脚本从其单行HTTP服务器返回的文本。

此外，它还展示了如何使用模块在不同环境中开发（不重复代码）Web服务器集群。

环境包括：

* 预发布环境 (stage)
* 生产环境 (prod)

此仓库的文件布局如下：

```bash
live
    ├── global
    │       └── s3/
    │           ├── main.tf
    │           └── (etc)
    │
    ├── stage
    │       ├── services/
    │       │   └── webserver-cluster/
    │       │       ├── main.tf
    │       │       └── (etc)
    │       └── data-stores/
    │           └── mysql/
    │               ├── main.tf
    │               └── (etc)
    │
    └── prod
            ├── services/
            │   └── webserver-cluster/
            │       ├── main.tf
            │       └── (etc)
            └── data-stores/
                └── mysql/
                    ├── main.tf
                    └── (etc)

modules
    └── services/
        └── webserver-cluster/
            ├── main.tf
            └── (etc)
```

两个环境共同使用的组件：

* Terraform 远程状态示例：[live/global/s3](live/global/s3)
* Terraform Web服务器集群模块示例：[modules/services/webserver-cluster](modules/services/webserver-cluster)

预发布环境使用的组件：

* Terraform MySQL on RDS 示例（预发布环境）：[live/stage/data-stores/mysql](live/stage/data-stores/mysql)
* Terraform Web服务器集群示例（预发布环境）：[live/stage/services/webserver-cluster](live/stage/services/webserver-cluster)

生产环境使用的组件：

* Terraform MySQL on RDS 示例（生产环境）：[live/prod/data-stores/mysql](live/prod/data-stores/mysql)
* Terraform Web服务器集群示例（生产环境）：[live/prod/services/webserver-cluster](live/prod/services/webserver-cluster)

## 系统要求

* 你必须在计算机上安装[Terraform](https://www.terraform.io/)。
* 你必须拥有[AWS (Amazon Web Services)](http://aws.amazon.com/)账户。
* 它使用Terraform AWS Provider，通过AWS API与AWS支持的众多资源进行交互。
* 此代码是为Terraform 0.10.x编写的。

## 使用代码

配置你的AWS访问密钥。

使用Terraform远程状态示例创建远程状态存储桶。参见：[live/global/s3](live/global/s3)

使用Terraform模块示例在预发布环境和生产环境中创建Web服务器集群。参见：[modules/services/webserver-cluster](modules/services/webserver-cluster)

使用Terraform MySQL on RDS示例在预发布环境中创建MySQL数据库。参见：[live/stage/data-stores/mysql](live/stage/data-stores/mysql)

使用Terraform Web服务器集群示例在预发布环境中创建Web服务器集群。参见：[live/stage/services/webserver-cluster](live/stage/services/webserver-cluster)

使用Terraform MySQL on RDS示例在生产环境中创建MySQL数据库。参见：[live/prod/data-stores/mysql](live/prod/data-stores/mysql)

使用Terraform Web服务器集群示例在生产环境中创建Web服务器集群。参见：[live/prod/services/webserver-cluster](live/prod/services/webserver-cluster)
