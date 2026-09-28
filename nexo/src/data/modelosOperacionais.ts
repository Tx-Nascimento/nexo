export const modelosOperacionais = [
  { id:'compras', setor:'Compras', operacao:'Compra de materiais', titulo:'POP — compra até o recebimento', conteudo:`MODELO OPERACIONAL — ADAPTAR E APROVAR ANTES DO USO
Versão: 1.0 | Responsável pela revisão: __________ | Aprovado em: __________

OBJETIVO
Garantir que a solicitação vire uma compra com condição negociada, prazo e recebimento comprovados.

ENTRADA
Solicitação com item, especificação, quantidade, unidade, data necessária e centro de custo. Solicitante: __________.

RESPONSABILIDADES
Solicitante: especificar e justificar a necessidade.
Comprador: cotar, comparar condições e acompanhar o fornecedor.
Gestor: validar prioridade e aprovar conforme a alçada interna.
Recebimento: conferir quantidade e condição do material.

PASSO A PASSO
1. Conferir especificação, saldo disponível e prazo necessário.
2. Registrar as propostas: fornecedor, preço, frete, impostos informados, prazo e pagamento. Não escolher apenas pelo menor preço unitário.
3. Registrar justificativa da escolha e solicitar a aprovação prevista pela empresa.
4. Emitir o pedido aprovado e obter confirmação escrita do fornecedor.
5. Registrar a próxima cobrança e a previsão de entrega.
6. Conferir o recebimento, registrar divergências e anexar evidência.
7. Concluir somente com recebimento confirmado ou encaminhamento formal da pendência.

SE HOUVER IMPEDIMENTO
Motivo: __________ | Quem deve responder: __________
Próxima ação: __________ | Previsão de retorno: __________

EVIDÊNCIAS
Solicitação, comparação de propostas, aprovação, pedido e confirmação do recebimento.

CRITÉRIO DE CONCLUSÃO
Material recebido e conferido; divergências resolvidas ou formalmente encaminhadas. Não concluir apenas porque o pedido foi enviado.` },
  { id:'fiscal', setor:'Fiscal', operacao:'Conferência de nota fiscal', titulo:'Checklist — nota, pedido e recebimento', conteudo:`MODELO OPERACIONAL — CONFERÊNCIA DOCUMENTAL
Versão: 1.0 | Revisor: __________ | Data: __________
Documento: __________ | Fornecedor: __________ | Pedido: __________

ANTES DO LANÇAMENTO
[ ] Documento recebido pelo canal definido pela empresa.
[ ] Fornecedor e destinatário conferidos.
[ ] Pedido localizado e condição negociada disponível.
[ ] Itens, unidades e quantidades comparados com o recebimento.
[ ] Valores, frete e descontos confrontados com o pedido.
[ ] Estoque/local de recebimento confirmado pelo responsável.
[ ] Centro de custo e classificação interna encaminhados ao responsável competente.
[ ] Tratamento fiscal validado pela pessoa habilitada segundo as regras da empresa.

DIVERGÊNCIA
Item/campo: __________
Valor esperado: __________ | Valor recebido: __________
Responsável pelo retorno: __________ | Prazo: __________
Próxima ação: __________ | Evidência anexada: __________

ENCERRAMENTO
[ ] Divergências resolvidas e evidências anexadas.
[ ] Conferência registrada por pessoa identificada.
[ ] Lançamento concluído e referência registrada.
[ ] Pendências comunicadas aos envolvidos.

Este checklist organiza a operação; não define enquadramento tributário nem substitui a validação fiscal.` },
  { id:'pcp', setor:'PCP', operacao:'Programação do turno', titulo:'Roteiro — programação e passagem de turno', conteudo:`MODELO OPERACIONAL — PROGRAMAÇÃO DO TURNO
Data: __________ | Turno: __________ | Responsável: __________

ENTRADAS PARA O PLANO
Pedidos/prioridades: __________
Estoque confirmado em: __________
Disponibilidade de matéria-prima e embalagens: __________
Capacidade disponível e restrições: __________

PLANO
Produto | Quantidade prevista | Linha | Início previsto | Responsável
__________ | __________ | __________ | __________ | __________

VALIDAÇÃO
[ ] Prioridades alinhadas com a liderança.
[ ] Materiais críticos confirmados.
[ ] Restrições de capacidade registradas.
[ ] Sequência comunicada à produção.
[ ] Versão do plano aprovada e identificada.

ACOMPANHAMENTO
Previsto: __________ | Realizado: __________ | Diferença: __________
Motivo da diferença: __________
Ação corretiva: __________ | Responsável: __________ | Prazo: __________

PASSAGEM DE TURNO
O que foi concluído: __________
O que continua em andamento: __________
O que está bloqueado e por quê: __________
Quem precisa responder e até quando: __________
Próxima ação confirmada: __________

CRITÉRIO DE CONCLUSÃO
Plano validado, comunicado e versão final registrada. Alterações posteriores devem preservar o histórico e a justificativa.` },
  { id:'reuniao', setor:'Gestão', operacao:'Reunião diária', titulo:'Pauta — alinhamento de 15 minutos', conteudo:`MODELO — REUNIÃO DIÁRIA DE OPERAÇÃO
Data: __________ | Equipe: __________ | Facilitador: __________

1. O QUE PRECISA SER ENTREGUE HOJE? (4 minutos)
Atividade | Responsável | Prazo | Resultado esperado
__________ | __________ | __________ | __________

2. O QUE ESTÁ PARADO? (5 minutos)
Impedimento | Quem resolve | Próxima ação | Previsão de retorno
__________ | __________ | __________ | __________

3. O QUE PRECISA DE DECISÃO? (3 minutos)
Decisão | Aprovador | Informação faltante | Até quando
__________ | __________ | __________ | __________

4. CONFIRMAR COMBINADOS (3 minutos)
[ ] Cada ação tem uma pessoa responsável.
[ ] Prazos e dependências foram atualizados no NEXO.
[ ] Mudanças de prioridade foram comunicadas.
[ ] O problema foi discutido com contexto, sem transformar pontuação em avaliação isolada.

Não listar toda a carteira: concentrar em entrega do dia, impedimentos e decisões.` }
]
