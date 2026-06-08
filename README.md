# 🚚 Análise de Performance Logística (E-commerce Olist)

## 📌 Contexto e Problema de Negócio
No mercado de e-commerce brasileiro, a eficiência logística é um fator crítico para a retenção de clientes e para a saúde financeira da operação. Devido às dimensões continentais do país, os prazos de entrega e os custos de frete variam drasticamente entre as regiões, criando gargalos ocultos que impactam diretamente a experiência do consumidor.

O objetivo deste projeto foi realizar um diagnóstico completo da performance de entregas da plataforma (utilizando a base de dados real e histórica da Olist). Para isso, construí um "Paredão de Métricas" gerencial focado em responder de uma só vez:
1. Qual o volume de vendas de cada estado?
2. Quanto tempo de fato demora para o produto chegar?
3. Qual a real gravidade dos atrasos por região?
4. Os fretes mais caros estão atrelados aos maiores prazos?

## 🛠️ Competências Técnicas Demonstradas (SQL Avançado)
* **Banco de Dados:** SQLite
* **Boas Práticas de Engenharia de Dados:**
  * **CTEs (Common Table Expressions):** Utilizada para consolidar o valor total do frete por pedido antes da média final, garantindo a granularidade correta e evitando duplicidade de valores.
  * **Prevenção de Truncamento (`CAST AS FLOAT`):** Aplicação de conversão de tipos de dados para evitar o erro clássico de "divisão de inteiros" do SQL, garantindo precisão matemática nas taxas percentuais.
  * **Engenharia de Datas (`JULIANDAY`):** Manipulação e cálculo dinâmico do tempo decorrido entre timestamps de compra e recebimento.
  * **Lógica Condicional Avançada:** Uso de `CASE WHEN` atrelado a funções de agregação para mapeamento de desvios operacionais (atrasos).
  * **Clean Code:** Código totalmente estruturado, indentado e documentado com comentários técnicos.

## 💡 Principais Insights Estratégicos Descobertos

* **O Desafio da Região Norte (Prazos e Eficiência):** Estados como Roraima (RR), Amapá (AP) e Amazonas (AM) enfrentam barreiras geográficas severas, liderando o ranking com médias de entrega superiores a 26 dias e registrando as maiores taxas proporcionais de atraso da plataforma.
* **A Anomalia Comercial da Paraíba (PB):** Contrariando a premissa de que os maiores prazos geram os fretes mais caros, a análise revelou que o estado da **Paraíba (PB)** possui o frete médio mais caro do Brasil, mesmo entregando em menos tempo que os estados do Norte. Este insight aponta uma oportunidade clara para a diretoria logística renegociar contratos com transportadoras ou planejar novos hubs de distribuição no Nordeste.

---

## 💻 Script SQL Otimizado (Single-Scan Query)

Para garantir máxima performance computacional, as métricas de tempo, volume e custo foram unificadas em uma única instrução, fazendo com que o banco de dados leia as tabelas principais apenas uma vez.

```sql
/* --------------------------------------------------------------------------------------
   PROJETO 1: PERFORMANCE LOGÍSTICA (E-COMMERCE OLIST)
   Objetivo: Analisar tempo de entrega, taxa de atraso e custo de frete por estado
   em uma única visão unificada.
----------------------------------------------------------------------------------------- */

-- CTE para somar o frete de todos os itens dentro de um mesmo pedido
WITH frete_por_pedido AS (
    SELECT 
        order_id,
        SUM(freight_value) AS frete_total_pedido
    FROM tb_order_items
    GROUP BY order_id
)

-- Consulta Principal unindo Tempo, Atrasos e Custo de Frete
SELECT 
    c.customer_state AS estado_destino,
    COUNT(o.order_id) AS total_pedidos,
    
    /* Métrica 1: Tempo médio de entrega (Dias)
       O JULIANDAY() é uma função específica do SQLite (outros bancos como PostgreSQL ou MySQL usaria função como DATEDIFF).
       Data de entrega ao cliente menos data de compra do produto, assim tenho os dias de entrega, usei avg para média */
    ROUND(AVG(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp)), 1) AS media_dias_entrega,
    
    /* Métrica 2: Volume total de pedidos atrasados
       Se a data de entrega ao cliente for maior que a data estimado então pedido foi entregue em atrasado */
    SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS pedidos_atrasados,
    
    /* Métrica 3: Percentual de atraso (%)
       Utilizei o CAST AS FLOAT para forçar a conversão do número inteiro em decimal.
       Isso previne o erro de "divisão de inteiros" do SQL, que arredondaria o resultado para zero e invalidaria a porcentagem */
    ROUND(
        (CAST(SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END) AS FLOAT) 
        / COUNT(o.order_id)) * 100, 1) AS percentual_atraso,
        
    /* Métrica 4: Custo médio do frete por pedido no estado
       Usei AVG para puxar média e no final GROUP BY agrupei por estado*/
    ROUND(AVG(f.frete_total_pedido), 2) AS custo_medio_frete
FROM tb_orders AS o

JOIN tb_customers AS c
    ON o.customer_id = c.customer_id
    
JOIN frete_por_pedido AS f
    ON o.order_id = f.order_id

-- Usei o comando WHERE para eliminar os campos NULL
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    
-- Ao agrupar por estado, tenho a certeza de que a média é por estado e não por Brasil inteiro
GROUP BY c.customer_state

ORDER BY percentual_atraso DESC; -- Quero ver o maior atraso
