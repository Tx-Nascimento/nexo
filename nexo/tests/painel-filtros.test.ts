import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'
import { beforeAll, beforeEach, afterEach, afterAll, expect, it } from 'vitest'

const read = (p: string) => readFileSync(new URL(p, import.meta.url), 'utf8')
const id = (n: number) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`
let db: PGlite
async function login(n: number) {
  await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub','${id(n)}',false);`)
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
  await db.exec('update operacoes set ativo=true');
  await db.exec(read('../sql/002_acesso_empresa.sql'))
  await db.exec(read('../sql/003_papeis_operacionais.sql'))
  await db.exec(read('../sql/004_operacional_integrado.sql'))
  await db.exec(read('../sql/005_painel_com_filtros.sql'))
  await db.exec(read('../sql/005_painel_com_filtros.sql'))
}, 60000)
beforeEach(async () => { await db.exec('begin;') })
afterEach(async () => { await db.exec('rollback; reset role;') })
afterAll(async () => { await db.close() })

async function painel(setor: number | null = null, op: number | null = null) {
 return (await db.query<{v:any}>(`select nexo_painel_filtrado(30,${setor ? "'"+id(setor)+"'" : 'null'},${op ? "'"+id(op)+"'" : 'null'}) v`)).rows[0].v
}
async function preparar() {
 await db.exec(`insert into setores(id,empresa_id,nome,ativo) values('${id(801)}','${id(1)}','Compras',true),('${id(802)}','${id(1)}','Fiscal',true),('${id(803)}','${id(2)}','Externo',true);
 update operacoes set setor_id='${id(801)}' where id='${id(301)}';
 insert into operacoes(id,empresa_id,setor_id,nome,ativo) values('${id(302)}','${id(1)}','${id(802)}','Nota fiscal',true);`)
 await login(201); await db.exec(`insert into execucoes(id,operacao_id,responsavel_id,titulo,status) values('${id(402)}','${id(302)}','${id(103)}','Nota fiscal','NAO_INICIADA')`)
}
it('setor e operação recortam todos os agregados e a fila', async () => {
 await preparar(); const p=await painel(801,301); expect(p.abertas).toBe(1); expect(p.fila).toHaveLength(1); expect(p.fila[0].id).toBe(id(401)); expect(p.equipe).toHaveLength(1); expect(p.gargalos[0].nome).toBe('Compras'); expect((await painel()).abertas).toBe(2)
})
it('operacional não ganha acesso selecionando setor alheio', async () => {
 await preparar(); await login(202); expect((await painel(802,302)).abertas).toBe(0); const c=(await db.query<{v:any}>('select nexo_filtros_painel() v')).rows[0].v; expect(c.operacoes.map((o:any)=>o.id)).toEqual([id(301)])
})
it('não aceita filtro de empresa diferente', async () => {
 await preparar(); await expect(painel(803)).rejects.toThrow('Filtro indisponível')
})
it('combinação de setor e operação incompatíveis é rejeitada', async () => {
 await preparar(); await expect(painel(801,302)).rejects.toThrow('Filtro indisponível')
})
it('demanda sem execução respeita setor e operação', async () => {
 await preparar(); await db.exec(`insert into demandas(id,empresa_id,setor_id,operacao_id,solicitante_id,responsavel_id,titulo,status) values('${id(901)}','${id(1)}','${id(802)}','${id(302)}','${id(101)}','${id(103)}','Conferir NF','ABERTA')`); expect((await painel(801)).demandas_abertas).toBe(0); expect((await painel(802,302)).demandas_abertas).toBe(1)
})
it('ocultar pontuação continua valendo no painel filtrado', async () => {
 await preparar(); await db.exec("select nexo_configurar_pontuacao('GESTAO')"); await login(202); const p=await painel(801); expect(p.pontuacao_visivel).toBe(false); expect(p.equipe.every((x:any)=>x.pontuacao===null)).toBe(true)
})
it('anônimo não executa catálogo nem painel filtrado', async () => {
 await db.exec('set role anon; savepoint anonimo'); await expect(db.exec('select nexo_filtros_painel()')).rejects.toThrow('permission denied'); await db.exec('rollback to savepoint anonimo'); await expect(db.exec('select nexo_painel_filtrado(30)')).rejects.toThrow('permission denied')
})
it('diagnóstico de testes é somente leitura e pode ser executado', async () => {
 await db.exec(read('../sql/005_diagnostico_testes.sql')); expect((await db.query('select id from execucoes')).rows).toHaveLength(1)
})
