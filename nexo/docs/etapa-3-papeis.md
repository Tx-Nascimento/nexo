# Etapa 3 — executar, conferir e aprovar

Aplicar depois da etapa 2A. O banco é atualizado por Tiago no Supabase;
o frontend é publicado pelo PR após validar a prévia.

## Regras

| Papel/vínculo | Ação |
| --- | --- |
| ADMIN e DIRETORIA | Executar atividades da própria empresa. |
| LIDER, GESTOR e GERENTE | Executar atividades do próprio setor; setor vazio não concede acesso. |
| Responsável / participante RESPONSAVEL ou EXECUTOR | Executar a atividade vinculada. |
| Conferente indicado | Consultar a execução e responder à conferência atribuída. |
| Aprovador indicado | Consultar a execução e responder à aprovação atribuída. |
| AUDITOR | Consulta nas ações operacionais desta etapa, mesmo se vinculado como responsável. |
| Outros participantes | Consulta, sem adquirir escrita por conseguir visualizar. |

Só a pessoa indicada responde; ADMIN não responde em nome dela. O mesmo
usuário pode acumular vínculos se for indicado explicitamente: esta etapa
não impõe obrigatoriamente pessoas diferentes para executar/conferir/aprovar.
O indicado precisa ter cadastro e acesso ativos na empresa e não ser AUDITOR.

## Fluxo

1. Executor solicita conferência ou aprovação. O banco grava a solicitação,
   o status aguardando e o histórico na mesma transação.
2. A pessoa indicada aprova ou rejeita. Rejeição exige motivo. A data da
   resposta é definida pelo banco; o ator entra no histórico de decisões.
3. O executor retoma a atividade ou conclui quando todos os requisitos forem
   atendidos. A resposta não muda automaticamente o status da execução.

Não se pode excluir, trocar o destinatário ou reescrever uma decisão
respondida pela API. Após rejeição, criar uma nova solicitação quando a
correção estiver pronta. Não há duas solicitações pendentes da mesma etapa.
Conclusão exige a decisão mais recente aprovada, quando obrigatória, e
nenhuma etapa pendente ou última resposta rejeitada, mesmo que opcional.
Bloqueios, dependências, retrabalhos e evidências também são verificados no
banco, inclusive em UPDATE direto. Execução encerrada não pode ser reaberta
por um simples UPDATE.

Redistribuição do responsável, mudança da operação e exclusão da execução
ficam bloqueadas na API; exigem um fluxo específico posterior. A criação de
execuções continua com as políticas anteriores (ADMIN); não foi expandida.

## Aplicar e validar

1. Supabase > SQL Editor > New query, como `postgres`.
2. Executar TODO `sql/003_papeis_operacionais.sql`.
3. Esperar `ETAPA 3 APLICADA` e usar a prévia do PR para os testes abaixo.
4. Evitar operar a tela antiga de conferência/aprovação no intervalo entre
   aplicar o SQL e publicar o frontend: ela ainda tenta alterar o status após
   cada resposta e registra a solicitação em chamadas separadas.

Teste com executor, conferente e aprovador diferentes: executor solicita;
outros não conseguem responder em seu lugar; indicado responde; rejeição
bloqueia conclusão; nova decisão aprovada libera quando não há outras pendências.
ADMIN não deve conseguir responder pela pessoa indicada. AUDITOR não deve
conseguir alterar progresso/status. Login e consulta de outra empresa continuam
bloqueados conforme etapa 2A.

Mudanças no banco: funções, triggers, políticas restritivas, ACL da RPC de
conclusão e nova tabela `nexo_decisao_historico`. Não modifica registros antigos.
Os testes locais usam PostgreSQL/PGlite com dados fictícios; não acessam o
Supabase real e não reproduzem todas as constraints e integrações.

## Reversão e próximos passos

Executar `sql/003_reverter_papeis_operacionais.sql` como postgres para restaurar
as regras operacionais anteriores e reverter o PR do frontend se já publicado.
A tabela de histórico e seus registros são preservados. A RPC de conclusão
continua sem chamada anônima, mesmo após a reversão.

Conversão de demandas em transação única, reabertura/redistribuição, notificações,
filas pessoais de decisão, cancelamento/reatribuição de solicitações pendentes
e revisão dos demais RPCs/Storage seguem como etapas posteriores.
