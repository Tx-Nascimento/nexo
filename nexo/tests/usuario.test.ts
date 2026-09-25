import { beforeEach, describe, expect, it, vi } from 'vitest'

const mock = vi.hoisted(() => ({ getUser: vi.fn(), from: vi.fn(), single: vi.fn() }))
vi.mock('../src/lib/supabase', () => ({ supabase: { auth: { getUser: mock.getUser }, from: mock.from } }))
import { buscarUsuarioAtual } from '../src/services/nexoService'

const registro = () => ({ pessoa_id: 'p1', ativo: true, pessoa: { nome: 'Teste', empresa_id: 'e1', ativo: true }, perfil: { nome: 'ADMIN' } })
beforeEach(() => {
  vi.clearAllMocks()
  mock.getUser.mockResolvedValue({ data: { user: { id: 'u1' } }, error: null })
  mock.from.mockReturnValue({ select: () => ({ eq: () => ({ maybeSingle: mock.single }) }) })
  mock.single.mockResolvedValue({ data: registro(), error: null })
})
describe('validação do usuário', () => {
  it('retorna o perfil e a empresa associados ao usuário autenticado', async () => {
    expect(await buscarUsuarioAtual()).toEqual({ pessoaId: 'p1', empresaId: 'e1', nome: 'Teste', perfil: 'ADMIN' })
  })
  it('normaliza relacionamentos retornados como listas', async () => {
    const r = registro()
    mock.single.mockResolvedValue({ data: { ...r, pessoa: [r.pessoa], perfil: [r.perfil] }, error: null })
    expect((await buscarUsuarioAtual())?.perfil).toBe('ADMIN')
  })
  it('retorna null sem sessão e não consulta tabelas', async () => {
    mock.getUser.mockResolvedValue({ data: { user: null }, error: { name: 'AuthSessionMissingError' } })
    expect(await buscarUsuarioAtual()).toBeNull()
    expect(mock.from).not.toHaveBeenCalled()
  })
  it('distingue erro de rede de ausência de sessão', async () => {
    mock.getUser.mockResolvedValue({ data: { user: null }, error: { name: 'AuthRetryableFetchError' } })
    await expect(buscarUsuarioAtual()).rejects.toThrow('validar a sessão')
  })
  it.each([
    [null, 'sem acesso'],
    [{ ...registro(), ativo: false }, 'desativado'],
    [{ ...registro(), pessoa: null }, 'incompleto'],
    [{ ...registro(), perfil: [] }, 'incompleto'],
    [{ ...registro(), pessoa: { ...registro().pessoa, ativo: false } }, 'inativo'],
  ])('bloqueia cadastro inválido: %j', async (data, mensagem) => {
    mock.single.mockResolvedValue({ data, error: null })
    await expect(buscarUsuarioAtual()).rejects.toThrow(mensagem as string)
  })
})
