# ⚙️ Integrações ADVPL (ERP Protheus)

Uma coleção de integrações, rotinas customizadas e automações desenvolvidas em **ADVPL** para o ecossistema do ERP TOTVS Protheus. O objetivo deste repositório é centralizar soluções que otimizam regras de negócio, facilitam a comunicação com sistemas externos e automatizam tarefas de alto volume.

## 🚀 O que você vai encontrar aqui

Este repositório contém scripts e projetos focados na extensão das capacidades nativas do Protheus, englobando:

- **APIs REST e Webservices:** Criação de endpoints customizados (FWRest) para consumo externo e rotinas de integração que consomem APIs de terceiros (JSON/XML).
- **Automação Financeira e Contábil:** Rotinas customizadas (Pontos de Entrada, ExecAuto) com foco nos módulos críticos do sistema, como **SIGAFIN** (Financeiro) e **SIGACTB** (Contabilidade).
- **Processamento de Dados em Massa:** Soluções para leitura, tratamento e gravação de arquivos (TXT, CSV) integrados ao banco de dados do ERP.
- **Consultas SQL Avançadas:** Queries otimizadas (Embedded SQL) para extração de relatórios e painéis gerenciais.

## 🛠️ Tecnologias e Ferramentas

- **Linguagem:** ADVPL / TL++
- **Banco de Dados:** SQL Server / Oracle (via TopConnect / DBAccess)
- **Protocolos:** REST, SOAP, HTTP
- **Formatos:** JSON, XML, CSV, TXT

## 📁 Estrutura do Repositório

*(Estrutura sugerida - adicione as pastas conforme subir os códigos)*

- `/Rest_APIs`: Classes para consumo e disponibilização de APIs.
- `/ExecAuto`: Exemplos de rotinas automáticas para inclusão de notas, títulos e clientes.
- `/PontosDeEntrada`: Customizações que alteram o comportamento padrão (PEs).
- `/Processamento`: Rotinas de leitura de arquivos e integrações via banco.

## 👨‍💻 Autor

Desenvolvido por **Bruno Domingos**.

---
*Focado em transformar processos manuais e complexos em integrações sólidas e escaláveis no ambiente Protheus.*
