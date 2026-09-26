import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'
import { beforeAll, beforeEach, afterEach, afterAll, expect, it } from 'vitest'

const read = (p: string) => readFileSync(new URL(p, import.meta.url), 'utf8')
const id = (n: number) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`
let db: PGlite
async function login(n: number) {
  await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub','${id(n)}',false);`)
}
async function pedir(tipo = 'conferencias', pessoa = 103) {
  const campo = tipo === 'conferencias' ? 'conferente_id' : 'aprovador_id'
  const resultado = tipo === 'conferencias' ? 'resultado' : 'status'
  await login(202)
  await db.exec(`insert into ${tipo}(id,execucao_id,${campo},${resultado}) values('${id(501)}','${id(401)}','${id(pessoa)}','PENDENTE');`)
}
beforeAll(async () => {
  db = new PGlite()
  await db.exec(read('./fixtures/acesso_antes.sql'))
  await db.exec(`
    insert into empresas(id,nome,ativo) values('${id(1)}','A',true),('${id(2)}','B',true);
    insert into perfis(id,nome) values('${id(10)}','ADMIN'),('${id(11)}','EXECUTOR'),('${id(12)}','AUDITOR'),('${id(13)}','GESTOR');
    insert into pessoas(id,empresa_id,nome,ativo) values
      ('${id(101)}','${id(1)}','Admin',true),('${id(102)}','${id(1)}','Executor',true),
      ('${id(103)}','${id(1)}','Conferente',true),('${id(104)}','${id(1)}','Aprovador',true),
      ('${id(105)}','${id(1)}','Auditor',true),('${id(106)}','${id(1)}','Observador',true),
      ('${id(107)}','${id(2)}','Outra empresa',true),('${id(108)}','${id(1)}','Gestor sem setor',true);
    insert into usuarios(id,pessoa_id,perfil_id,ativo) values
      ('${id(201)}','${id(101)}','${id(10)}',true),('${id(202)}','${id(102)}','${id(11)}',true),
      ('${id(203)}','${id(103)}','${id(11)}',true),('${id(204)}','${id(104)}','${id(11)}',true),
      ('${id(205)}','${id(105)}','${id(12)}',true),('${id(206)}','${id(106)}','${id(11)}',true),
      ('${id(207)}','${id(107)}','${id(10)}',true),('${id(208)}','${id(108)}','${id(13)}',true);
    insert into operacoes(id,empresa_id,nome,exige_conferencia,exige_aprovacao,exige_evidencia)
      values('${id(301)}','${id(1)}','Operação',true,true,false);
    insert into execucoes(id,operacao_id,responsavel_id,titulo,status,percentual_conclusao)
      values('${id(401)}','${id(301)}','${id(102)}','Atividade','EM_EXECUCAO',0);
    insert into execucao_participantes(execucao_id,pessoa_id,papel,ativo)
      values('${id(401)}','${id(106)}','OBSERVADOR',true);
  `)
  await db.exec(read('../sql/002_acesso_empresa.sql'))
  await db.exec(read('../sql/003_papeis_operacionais.sql'))
  await db.exec(read('../sql/003_papeis_operacionais.sql'))
}, 60000)
beforeEach(async () => { await db.exec('begin;') })
afterEach(async () => { await db.exec('rollback; reset role;') })
afterAll(async () => { await db.close() })

it('solicitação, status e histórico são gravados na mesma transação', async () => {
  await pedir()
  expect((await db.query(`select status from execucoes`)).rows).toEqual([{ status: 'AGUARDANDO_CONFERENCIA' }])
  expect((await db.query(`select acao,ator_id from nexo_decisao_historico`)).rows).toEqual([{ acao: 'SOLICITADA', ator_id: id(102) }])
  expect((await db.query(`select status_novo from execucao_status_historico`)).rows).toEqual([{ status_novo: 'AGUARDANDO_CONFERENCIA' }])
})
it('conferente ganha leitura, mas não pode executar nem concluir pela RPC', async () => {
  await pedir()
  await login(203)
  expect((await db.query(`select id from execucoes`)).rows).toHaveLength(1)
  expect((await db.query(`update execucoes set percentual_conclusao=100 returning id`)).rows).toHaveLength(0)
  await expect(db.exec(`select nexo_concluir_execucao('${id(401)}');`)).rejects.toThrow('permissão para executar')
})
it('só o conferente indicado responde, nem ADMIN pode responder por ele', async () => {
  await pedir()
  await login(201)
  expect((await db.query(`update conferencias set resultado='APROVADA' returning id`)).rows).toHaveLength(0)
  await login(203)
  expect((await db.query(`update conferencias set resultado='APROVADA' returning id,finalizado_em`)).rows[0].finalizado_em).toBeTruthy()
  expect((await db.query(`select acao,ator_id from nexo_decisao_historico order by ocorrido_em`)).rows[1]).toEqual({ acao: 'APROVADA', ator_id: id(103) })
})
it('só o aprovador indicado pode aprovar', async () => {
  await pedir('aprovacoes',104)
  await login(202)
  expect((await db.query(`update aprovacoes set status='APROVADA' returning id`)).rows).toHaveLength(0)
  await login(204)
  expect((await db.query(`update aprovacoes set status='APROVADA' returning id`)).rows).toHaveLength(1)
})
it('não permite forjar uma decisão aprovada na criação', async () => {
  await login(202)
  await expect(db.exec(`insert into conferencias(id,execucao_id,conferente_id,resultado) values('${id(501)}','${id(401)}','${id(103)}','APROVADA');`)).rejects.toThrow('pendente')
})
it('não permite trocar o conferente durante a resposta', async () => {
  await pedir()
  await login(203)
  await expect(db.exec(`update conferencias set conferente_id='${id(104)}',resultado='APROVADA';`)).rejects.toThrow('conferente')
})
it('não permite responder novamente nem reabrir uma decisão encerrada', async () => {
  await pedir()
  await login(203)
  await db.exec(`update conferencias set resultado='APROVADA';`)
  await expect(db.exec(`update conferencias set resultado='REJEITADA',observacao='Alteração posterior';`)).rejects.toThrow('já foi respondida')
})
it('rejeição exige motivo', async () => {
  await pedir()
  await login(203)
  await expect(db.exec(`update conferencias set resultado='REJEITADA';`)).rejects.toThrow('motivo')
})
it('não permite duas solicitações pendentes da mesma etapa', async () => {
  await pedir()
  await expect(db.exec(`insert into conferencias(id,execucao_id,conferente_id,resultado) values('${id(502)}','${id(401)}','${id(104)}','PENDENTE');`)).rejects.toThrow('Já existe')
})
it('não permite indicar pessoa de outra empresa', async () => {
  await expect(pedir('conferencias',107)).rejects.toThrow('pessoa da empresa')
})
it('auditor consulta mas não escreve', async () => {
  await pedir()
  await login(205)
  expect((await db.query(`select id from execucoes`)).rows).toHaveLength(1)
  expect((await db.query(`update execucoes set percentual_conclusao=70 returning id`)).rows).toHaveLength(0)
  await expect(db.exec(`insert into evidencias(execucao_id) values('${id(401)}');`)).rejects.toThrow(/row-level security/i)
})
it('observador não vira executor por conseguir visualizar a execução', async () => {
  await login(206)
  expect((await db.query(`select id from execucoes`)).rows).toHaveLength(1)
  expect((await db.query(`select nexo_pode_executar('${id(401)}') as permitido`)).rows).toEqual([{ permitido: false }])
})
it('gestor sem setor não ganha acesso às operações sem setor', async () => {
  await login(208)
  expect((await db.query(`select id from execucoes`)).rows).toHaveLength(0)
})
it('não permite burlar conclusão por UPDATE direto', async () => {
  await login(202)
  await expect(db.exec(`update execucoes set status='CONCLUIDA';`)).rejects.toThrow('última conferência')
})
it('conclui após as duas respostas e bloqueia alteração posterior', async () => {
  await pedir()
  await login(203)
  await db.exec(`update conferencias set resultado='APROVADA';`)
  await pedir('aprovacoes',104)
  await login(204)
  await db.exec(`update aprovacoes set status='APROVADA';`)
  await login(202)
  await db.exec(`select nexo_concluir_execucao('${id(401)}');`)
  expect((await db.query(`select status from execucoes`)).rows).toEqual([{ status: 'CONCLUIDA' }])
  await expect(db.exec(`update execucoes set status='EM_EXECUCAO';`)).rejects.toThrow('encerrada')
})
it('decisão antiga não supera uma nova rejeição', async () => {
  await pedir()
  await login(203)
  await db.exec(`update conferencias set resultado='APROVADA';`)
  await login(202)
  await db.exec(`insert into conferencias(id,execucao_id,conferente_id,resultado) values('${id(502)}','${id(401)}','${id(103)}','PENDENTE');`)
  await login(203)
  await db.exec(`update conferencias set resultado='REJEITADA',observacao='Correção necessária' where id='${id(502)}';`)
  await login(202)
  await expect(db.exec(`update execucoes set status='CONCLUIDA';`)).rejects.toThrow('última conferência')
})
it('histórico de decisão não pode ser falsificado pela API', async () => {
  await login(201)
  await expect(db.exec(`insert into nexo_decisao_historico(execucao_id,solicitacao_id,etapa,acao,ator_id) values('${id(401)}','${id(501)}','APROVACAO','APROVADA','${id(104)}');`)).rejects.toThrow(/permission denied/i)
})
it('rollback preserva histórico e restaura permissões anteriores', async () => {
  await pedir()
  await db.exec('commit; reset role;')
  await db.exec(read('../sql/003_reverter_papeis_operacionais.sql'))
  expect((await db.query(`select * from nexo_decisao_historico`)).rows).toHaveLength(1)
  await login(201)
  expect((await db.query(`update conferencias set resultado='APROVADA' returning id`)).rows).toHaveLength(1)
})
