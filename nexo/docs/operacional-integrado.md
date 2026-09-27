# Operacional integrado

## Ativação

1. As migrações 002 e 003 precisam estar aplicadas.
2. No Supabase do NEXO, abrir **SQL Editor → New query**, usando `postgres`.
3. Copiar e executar **todo** `sql/004_operacional_integrado.sql`. O resultado deve ser `PACOTE OPERACIONAL APLICADO`.
4. Usar a prévia do PR para conferir um login de diretoria, um chefe e um operacional. Publicar o frontend após confirmar a aplicação do SQL.

O script roda em transação e pode ser reaplicado. Não apaga dados, tabelas ou colunas existentes. Acrescenta `motivo_gestao` em demandas/execuções, três tabelas de governança/histórico, funções, políticas e triggers. Preserva os cadastros de operação, responsabilidades, recorrências, exigências de evidência/conferência/aprovação e vínculos existentes. No intervalo entre aplicar o banco e trocar o frontend, evite lançamentos pela versão anterior: ela ainda tenta gravar participantes e históricos separadamente.

## Visibilidade e controles

| Perfil | Visão | Controles |
| --- | --- | --- |
| ADMIN / DIRETORIA | Toda a própria empresa | Gestão operacional, redistribuição, prazos, reabertura justificada e configuração da pontuação |
| LIDER / GESTOR / GERENTE | Próprio setor e cadeia de subordinados cadastrada em `pessoas.gestor_id` | Gestão das atividades no escopo e atribuição a pessoas da equipe |
| Operacional | Execuções atribuídas ou com participação; demandas próprias como responsável/solicitante | Execução, progresso, evidências e tratamento de impedimentos conforme vínculo |
| Conferente/aprovador | Atividades necessárias à decisão atribuída | Responder somente à própria solicitação |
| AUDITOR | Consulta da empresa, preservando perfil existente | Sem escrita operacional |

Setor vazio não significa acesso a todos. A cadeia de gestores encerra ciclos. A política do banco aplica o escopo; não depende apenas de esconder componentes. O diretório mínimo de seleção expõe nome/ID/setor da empresa para atribuição de decisões, sem e-mail ou dados de acesso. A alteração de usuários e perfis permanece exclusiva do ADMIN. DIRETORIA pode cadastrar processos, operações, responsabilidades e recorrências.

## Rotina de gestão

- **Diretor, semanalmente:** comparar entradas e conclusões; examinar atrasos por setor, motivos de bloqueio, idade da carteira, SLA e retrabalho. Cobrar plano de ação para gargalos persistentes.
- **Chefe, diariamente:** revisar fila de atenção, definir responsável e prazo para demandas sem tratamento, distribuir carteira e liberar dependências. Registrar justificativa para mudanças de prazo e responsável.
- **Operacional, diariamente:** trabalhar na sua fila, manter progresso, registrar evidências e informar bloqueio/dependência com próxima ação e previsão de retorno. Solicitar conferência/aprovação quando exigidas.
- **Cadastros:** cada operação deve ter setor/processo, descrição do resultado esperado, responsáveis, prioridade, estimativa e requisitos de conclusão; recorrências guardam periodicidade, prazo e SLA. Não foram inventados cadastros ou metas da empresa.

## Indicadores

| Indicador | Regra |
| --- | --- |
| Carteira e atrasadas | Snapshot atual; concluídas/canceladas excluídas; atraso exige prazo vencido |
| Entregas e atendimento diário | Conclusões no período de 7, 30 ou 90 dias; entradas por criação da execução |
| No prazo | Entregas com conclusão até o prazo / entregas com prazo informado |
| SLA | Conclusões dentro dos minutos de SLA; exige início válido e SLA positivo |
| Ciclo | Média de horas entre início e conclusão, excluindo datas ausentes/invertidas |
| Retrabalho | Percentual de entregas que tiveram pelo menos um retrabalho |
| Gargalos | Carteira por etapa/setor, motivos dos bloqueios ativos e idade desde criação |
| Demandas abertas | Demandas não encerradas e ainda sem execução, sem contar duas vezes a carteira |
| Distribuição | Quantidade aberta/atrasada e entregas por responsável; não equivale a capacidade em horas |

Períodos e agrupamentos diários usam UTC, indicado no gráfico. Datas individuais são apresentadas no fuso do navegador. Ausência de amostra aparece como `Sem amostra`, não como 100%. Os agregados são calculados no PostgreSQL, sem depender do limite de linhas de consultas REST. A fila mostra as primeiras 50 atividades priorizadas; motivos de bloqueio mostram os 10 mais frequentes. Os contadores não são limitados a essas listas.

## Pontuação

A nota exibida passa a ser explícita: **pontualidade de 0 a 100**, com amostra visível. Substitui a composição antiga no navegador que imputava desempenho com dados ausentes. Não representa avaliação completa de uma pessoa; qualidade/retrabalho e carga são apresentados separadamente.

Diretor/ADMIN escolhe no painel:

- **TODOS:** cada usuário recebe pontuação somente do próprio escopo.
- **GESTAO:** notas retornadas apenas a ADMIN/DIRETORIA/LIDER/GESTOR/GERENTE.
- **DESATIVADA:** nenhuma nota é calculada/retornada.

A configuração é aplicada no servidor e registrada em `nexo_governanca_historico`. Não impede que alguém calcule uma taxa por conta própria a partir de atividades às quais já tem acesso autorizado.

## Integridade operacional

Conversão usa bloqueio da demanda e uma transação: execução, participante, histórico e vínculo são gravados juntos. Repetir a conversão retorna o mesmo ID. Criação também gera participante/histórico no banco. Status/progresso da execução sincronizam a demanda vinculada; não se conclui uma demanda vinculada ignorando as exigências da execução.

Gestão de responsável/prazo/operação da demanda e redistribuição/reabertura da execução exige justificativa e gera `nexo_gestao_historico`. Reatribuir execução desativa o antigo participante RESPONSAVEL, preservando outros vínculos explícitos. Demandas vinculadas acompanham a execução. As decisões de aprovação/conferência continuam pessoais e preservam o histórico da etapa 003; reabertura não apaga decisões anteriores.

## Validação e limites

Testes automatizados usam PostgreSQL/PGlite com fixtures sintéticas, além dos testes de sessão/interface existentes, e build TypeScript/Vite. Não acessam o Supabase real nem reproduzem todas as constraints, extensões ou políticas Storage. A validação em ambiente real é feita após a aplicação pelo responsável do banco. Este pacote não configura e-mails, notificações push ou agendador automático de recorrências.

Para reverter as regras desta entrega, executar `sql/004_reverter_operacional_integrado.sql` e restaurar o frontend do PR anterior. Os registros e históricos novos são preservados.
