# Finanças

App Flutter de controle financeiro pessoal.

- Receitas e despesas com valor, descrição, categoria, data e moeda (Real, Dólar ou Euro)
- Criar categorias próprias (nome, ícone e cor); segure uma categoria criada para apagar
- Saldo, receitas e despesas do mês, com navegação entre meses
- Gráfico de despesas por categoria
- Lançamentos em Dólar ou Euro são convertidos automaticamente para Real com a cotação do dia (guardada no lançamento; sem internet usa a última cotação ou permite digitar)
- Saldo, gráfico e relatórios sempre em Real
- Exportar o mês em PDF (receitas, despesas ou completo) ou planilha (.csv)
- Dados guardados só no celular

O APK é compilado pelo GitHub Actions a cada envio para `main`
(aba **Actions → Build Android APK → Artifacts → financas-apk**).
