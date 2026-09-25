import { PGlite } from '@electric-sql/pglite'
import { readFileSync } from 'node:fs'
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from 'vitest'

const read = (path: string) => readFileSync(new URL(path, import.meta.url), 'utf8')
const id = (n: number) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`
let db: PGlite
async function login(n: number) {
  await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub', '${id(n)}', false);`)
}
async function count(table: string) {
  const r = await db.query<{ n: number }>(`select count(*)::int as n from public.${table}`)
  return r.rows[0].n
}
beforeAll(async () => {
  db = new PGlite()
  await db.exec(read('./fixtures/acesso_antes.sql'))
  await db.exec(`
    insert into empresas(id,nome,ativo) values ('${id(1)}','A',true), ('${id(2)}','B',true);
    insert into perfis(id,nome) values ('${id(10)}','ADMIN'), ('${id(11)}','EXECUTOR');
    insert into pessoas(id,empresa_id,nome,ativo) values
      ('${id(101)}','${id(1)}','Admin A',true),
      ('${id(102)}','${id(1)}','Comum A',true),
      ('${id(103)}','${id(2)}','Admin B',true),
      ('${id(104)}','${id(1)}','Inativo A',true),
      ('${id(105)}','${id(1)}','Admin A2',true);
    insert into usuarios(id,pessoa_id,perfil_id,ativo) values
      ('${id(201)}','${id(101)}','${id(10)}',true),
      ('${id(202)}','${id(102)}','${id(11)}',true),
      ('${id(203)}','${id(103)}','${id(10)}',true),
      ('${id(204)}','${id(104)}','${id(11)}',false),
      ('${id(205)}','${id(105)}','${id(10)}',true);
    insert into operacoes(id,empresa_id,nome) values ('${id(301)}','${id(1)}','A'),('${id(302)}','${id(2)}','B');
    insert into execucoes(id,operacao_id,responsavel_id,titulo) values
      ('${id(401)}','${id(301)}','${id(102)}','A'),('${id(402)}','${id(302)}','${id(103)}','B');
    insert into aprovacoes(id,execucao_id,aprovador_id,status) values
      ('${id(501)}','${id(401)}','${id(101)}','PENDENTE'),('${id(502)}','${id(402)}','${id(103)}','PENDENTE');
  `)
  // A segunda aplicação também deve funcionar sem duplicar políticas.
  await db.exec(read('../sql/002_acesso_empresa.sql'))
  await db.exec(read('../sql/002_acesso_empresa.sql'))
}, 60000)
beforeEach(async () => { await db.exec('begin;') })
afterEach(async () => { await db.exec('rollback; reset role;') })
afterAll(async () => { await db.close() })

describe('RLS aplicada em PostgreSQL local', () => {
  it('usuário comum lê seus vínculos necessários para login', async () => {
    await login(202)
    const r = await db.query(`select u.id, p.nome, pf.nome as perfil from usuarios u join pessoas p on p.id=u.pessoa_id join perfis pf on pf.id=u.perfil_id`)
    expect(r.rows).toEqual([{ id: id(202), nome: 'Comum A', perfil: 'EXECUTOR' }])
    expect(await count('operacoes')).toBe(1)
  })
  it('ADMIN lista e altera acessos somente da própria empresa', async () => {
    await login(201)
    expect(await count('usuarios')).toBe(4)
    const r = await db.query(`update usuarios set ativo=false where id='${id(202)}' returning id`)
    expect(r.rows).toEqual([{ id: id(202) }])
    expect((await db.query(`update usuarios set ativo=false where id='${id(203)}' returning id`)).rows).toEqual([])
  })
  it('ADMIN não lê nem altera execuções e aprovações da outra empresa', async () => {
    await login(201)
    expect(await count('execucoes')).toBe(1)
    expect(await count('aprovacoes')).toBe(1)
    expect((await db.query(`update execucoes set titulo='proibido' where id='${id(402)}' returning id`)).rows).toEqual([])
  })
  it('comum não promove seu próprio perfil', async () => {
    await login(202)
    expect((await db.query(`update usuarios set perfil_id='${id(10)}' where id='${id(202)}' returning id`)).rows).toEqual([])
  })
  it('não permite trocar a identidade vinculada pela API', async () => {
    await login(201)
    await expect(db.exec(`update usuarios set pessoa_id='${id(103)}' where id='${id(202)}'`)).rejects.toThrow(/permission denied/i)
  })
  it('ADMIN não pode inativar seu próprio acesso', async () => {
    await login(201)
    await expect(db.exec(`update usuarios set ativo=false where id='${id(201)}'`)).rejects.toThrow('outro administrador')
  })
  it('inativo lê a própria identidade mas não os dados operacionais', async () => {
    await login(204)
    expect(await count('usuarios')).toBe(1)
    expect(await count('pessoas')).toBe(1)
    expect(await count('execucoes')).toBe(0)
    expect(await count('operacoes')).toBe(0)
  })
  it('pessoa inativa também perde o escopo, mesmo com usuário ativo', async () => {
    // Simula inconsistência preexistente, sem desativar a proteção do banco real.
    await db.exec(`alter table pessoas disable trigger trg_nexo_002_proteger_pessoa; update pessoas set ativo=false where id='${id(102)}';`)
    await login(202)
    expect(await count('execucoes')).toBe(0)
    expect(await count('pessoas')).toBe(1)
  })
  it('não deixa inativar pessoa com login ativo', async () => {
    await login(201)
    await expect(db.exec(`update pessoas set ativo=false where id='${id(101)}'`)).rejects.toThrow('Desative primeiro')
  })
  it('não deixa transferir pessoa com login para outra empresa', async () => {
    await login(201)
    await expect(db.exec(`update pessoas set empresa_id='${id(2)}' where id='${id(101)}'`)).rejects.toThrow('Transferência')
  })
  it('último ADMIN é avaliado por empresa, não pelo total global', async () => {
    await db.exec(`select set_config('request.jwt.claim.sub', '', false);`)
    await expect(db.exec(`update usuarios set ativo=false where id='${id(203)}'`)).rejects.toThrow('último ADMIN ativo da empresa')
  })
  it('anônimo não lê usuários nem execuções', async () => {
    await db.exec(`set role anon; select set_config('request.jwt.claim.sub', '', false);`)
    expect(await count('usuarios')).toBe(0)
    expect(await count('execucoes')).toBe(0)
  })
  it('rollback restaura as permissões originais', async () => {
    // O arquivo tem sua própria transação; este caso não modifica dados.
    await db.exec('rollback; reset role;')
    await db.exec(read('../sql/002_reverter_acesso_empresa.sql'))
    await login(201)
    expect(await count('usuarios')).toBe(1)
    expect(await count('execucoes')).toBe(2)
    await db.exec('reset role;')
    await db.exec(read('../sql/002_acesso_empresa.sql'))
  })
})
