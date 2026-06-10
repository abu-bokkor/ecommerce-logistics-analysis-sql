/* --------------------------------------------------------------------------------------
   PROJETO 1: PERFORMANCE LOGÍSTICA (E-COMMERCE OLIST)
   Objetivo: Analisar tempo de entrega, taxa de atraso e custo de frete por estado
   e por mês em uma única visão unificada.
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
    
    -- Extraindo o Ano e Mês da compra para permitir filtros de linha do tempo no Power BI
    strftime('%Y-%m', o.order_purchase_timestamp) AS ano_mes_compra,
    
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
    
-- Ao agrupar por estado e mês, a certeza é de que a média é calculada para cada estado dentro de cada mês específico
GROUP BY c.customer_state, ano_mes_compra

ORDER BY ano_mes_compra ASC, percentual_atraso DESC; -- Ordenado por linha do tempo e maiores atrasos
