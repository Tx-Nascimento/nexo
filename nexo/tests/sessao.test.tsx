// @vitest-environment jsdom
import { act } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const mock = vi.hoisted(() => ({ buscar: vi.fn(), subscribe: vi.fn(), unsubscribe: vi.fn() }))
vi.mock('../src/lib/supabase', () => ({ supabase: { auth: { onAuthStateChange: mock.subscribe } } }))
vi.mock('../src/services/nexoService', () => ({ buscarUsuarioAtual: mock.buscar }))
import { useUsuario } from '../src/hooks/useUsuario'

const usuario = { pessoaId: 'p1', empresaId: 'e1', nome: 'Teste', perfil: 'ADMIN' }
let estado: ReturnType<typeof useUsuario>
let root: Root
let evento: (nome: string, sessao: unknown) => void
function Harness() { estado = useUsuario(); return null }
beforeEach(async () => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  vi.useFakeTimers()
  vi.clearAllMocks()
  mock.buscar.mockResolvedValue(usuario)
  mock.subscribe.mockImplementation((callback) => {
    evento = callback
    return { data: { subscription: { unsubscribe: mock.unsubscribe } } }
  })
  root = createRoot(document.createElement('div'))
  await act(async () => { root.render(<Harness />) })
  await act(async () => { await vi.runAllTimersAsync() })
})
afterEach(async () => { await act(async () => { root.unmount() }); vi.useRealTimers() })

describe('ciclo de sessão', () => {
  it('recupera o usuário na inicialização', () => {
    expect(estado.usuario).toEqual(usuario)
    expect(estado.inicializando).toBe(false)
  })
  it('não restaura acesso com uma resposta atrasada após logout', async () => {
    let resolver!: (valor: typeof usuario) => void
    mock.buscar.mockImplementationOnce(() => new Promise((resolve) => { resolver = resolve }))
    await act(async () => { window.dispatchEvent(new Event('focus')) })
    await act(async () => { evento('SIGNED_OUT', null) })
    await act(async () => { resolver(usuario) })
    expect(estado.usuario).toBeNull()
  })
  it('revalida o perfil após renovação fora do callback Auth', async () => {
    mock.buscar.mockResolvedValue({ ...usuario, perfil: 'EXECUTOR' })
    const chamadas = mock.buscar.mock.calls.length
    await act(async () => { evento('TOKEN_REFRESHED', { user: { id: 'u1' } }) })
    expect(mock.buscar).toHaveBeenCalledTimes(chamadas)
    await act(async () => { await vi.runAllTimersAsync() })
    expect(estado.usuario?.perfil).toBe('EXECUTOR')
  })
  it('remove o acesso se a revalidação detectar inativação', async () => {
    mock.buscar.mockRejectedValue(new Error('Seu acesso está desativado.'))
    await act(async () => { window.dispatchEvent(new Event('focus')) })
    expect(estado.usuario).toBeNull()
    expect(estado.erroAcesso).toContain('desativado')
  })
  it('cancela revalidação agendada quando ocorre logout', async () => {
    const chamadas = mock.buscar.mock.calls.length
    await act(async () => {
      evento('SIGNED_IN', { user: { id: 'u1' } })
      evento('SIGNED_OUT', null)
      await vi.runAllTimersAsync()
    })
    expect(mock.buscar).toHaveBeenCalledTimes(chamadas)
    expect(estado.usuario).toBeNull()
  })
})
