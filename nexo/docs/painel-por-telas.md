# Painel por telas, filtros e simulações

## Aplicação

1. Supabase → SQL Editor → New query, como postgres: executar inteiro `sql/005_painel_com_filtros.sql` após a etapa 004.
2. Esperar `PAINEL COM FILTROS APLICADO` e confirmar para publicar o frontend do PR.
3. Para revisar os testes antigos, executar separadamente `sql/005_diagnostico_testes.sql` e enviar o JSON retornado. É somente leitura; nomes contendo “teste”, “demo” e “simulação” são candidatos, não prova de que um registro pode ser excluído.

A etapa 005 acrescenta duas RPCs e suas permissões; não altera tabelas, registros ou as RPCs antigas. A versão anterior do frontend continua funcionando após a aplicação. Não executar a limpeza por palavras-chave. A remoção/arquivamento dos testes antigos depende da identificação dos IDs e vínculos reais; não foi realizada nesta entrega porque o agente não acessa diretamente o banco.

## Uso

O mesmo local tem as telas Resumo, Atendimento, Gargalos, Prioridades, Equipe, Simulações e, para a diretoria, Configuração. Só uma análise é exibida por vez. Resumo mostra quatro KPIs, atendimento e próximas ações; não empilha todas as seções.

Os filtros Setor, Operação e Período são compartilhados entre as telas enquanto o painel permanece aberto. Trocar de setor limpa a operação. Limpar filtros volta para todos no escopo e 30 dias. Filtros nunca ampliam permissões: as RPCs aplicam autorização antes de agregar.

Setor/Operação recortam carteira, entregas, qualidade, fluxo diário, causas, idade, decisões, fila e demandas sem execução. Equipe filtrada mostra responsáveis com atividades daquele recorte; não é um cadastro completo de lotação nem capacidade em horas. Pessoas sem execução no recorte não aparecem. Os agregados são calculados no PostgreSQL, sem truncamento pelo limite padrão da API REST.

Prioridades oferece busca sobre as 50 primeiras atividades retornadas; o limite está informado na tela. Cadastros e documentos continuam sujeitos às permissões existentes. A configuração da pontuação é empresarial e não muda de abrangência quando um filtro está selecionado.

## Simulações e repositório

Compras, Fiscal e PCP têm cenários realistas com etapas que avançam/reiniciam localmente. Eles não representam registros reais nem gravam no banco. O gráfico muda conforme o exercício e a identificação de simulação permanece visível. Recarregar/reabrir a tela reinicia o exercício.

Documentos ganhou busca por título/descrição, filtros de setor/operação (via `documento_vinculos`) e formulários recolhidos. Não foram alteradas as políticas de Storage nem a autorização existente de upload.

A aba Modelos prontos contém documentos efetivamente baixáveis em texto UTF-8:
- POP de compra até o recebimento;
- checklist de nota, pedido e recebimento;
- roteiro de programação e passagem de turno;
- pauta de reunião diária de 15 minutos.

São modelos editáveis para revisão e aprovação da empresa, não procedimentos aprovados. Para usá-los no repositório oficial: baixar, adaptar, aprovar e cadastrar a versão aprovada. Nenhum arquivo de terceiro ou documento empresarial foi inventado.

## Verificação e reversão

82 testes passaram, incluindo 8 testes PostgreSQL/PGlite para filtros/isolamento e 3 testes de interface para telas, troca de filtro e simulação sem escrita. Build TypeScript/Vite aprovado. Não houve teste no Supabase real; fixtures locais não reproduzem todas as constraints/integrações.

Reversão: restaurar o frontend anterior. As funções adicionais podem permanecer sem uso; o painel antigo e as políticas anteriores não foram substituídos. Para desativar as novas RPCs, revogar EXECUTE de authenticated em `nexo_filtros_painel()` e `nexo_painel_filtrado(integer,uuid,uuid)`. Não há dados novos a apagar.
