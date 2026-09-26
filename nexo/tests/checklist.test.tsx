// @vitest-environment jsdom
import { act } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { beforeEach, afterEach, expect, it, vi } from 'vitest'
const mock = vi.hoisted(() => ({ respostas: {} as Record<string, any> }))
vi.mock('../src/lib/supabase', () => ({ supabase: { from: (tabela: string) => {
  const builder: any = {
    select: () => builder, eq: () => builder, in: () => builder, order: () => builder,
    single: () => Promise.resolve(mock.respostas[tabela]),
    then: (resolve: (value: unknown) => void) => Promise.resolve(mock.respostas[tabela]).then(resolve),
  }
  return builder
} } }))
import ChecklistConclusao from '../src/components/ChecklistConclusao'
let root: Root
let container: HTMLDivElement
beforeEach(() => {
  Object.assign(globalThis, { IS_REACT_ACT_ENVIRONMENT: true })
  mock.respostas = {
    operacoes: { data: { exige_conferencia: true, exige_aprovacao: true, exige_evidencia: false } },
    conferencias: { data: [{ resultado: 'APROVADA' }] },
    aprovacoes: { data: [{ status: 'APROVADA' }] },
    bloqueios: { count: 0 }, dependencias: { count: 0 }, retrabalhos: { count: 0 }, evidencias: { count: 0 },
  }
  container = document.createElement('div')
  root = createRoot(container)
})
afterEach(async () => { await act(async () => { root.unmount() }) })
async function render(podeConcluir = true, revisao = 0) {
  await act(async () => { root.render(<ChecklistConclusao execucaoId="e1" operacaoId="o1" status="EM_EXECUCAO" onConcluir={() => {}} podeConcluir={podeConcluir} revisao={revisao} />) })
}
it('executor com requisitos atendidos pode concluir', async () => {
  await render()
  expect(container.querySelector('button')!.disabled).toBe(false)
})
it('revisor sem permissão de execução não pode concluir', async () => {
  await render(false)
  expect(container.querySelector('button')!.disabled).toBe(true)
})
it('nova rejeição supera aprovação anterior no checklist', async () => {
  mock.respostas.conferencias.data = [{ resultado: 'REJEITADA' }, { resultado: 'APROVADA' }]
  await render()
  expect(container.querySelector('button')!.disabled).toBe(true)
})
it('etapa opcional pendente também bloqueia conclusão', async () => {
  mock.respostas.operacoes.data.exige_conferencia = false
  mock.respostas.conferencias.data = [{ resultado: 'PENDENTE' }]
  await render()
  expect(container.querySelector('button')!.disabled).toBe(true)
})
it('nova consulta com erro não conserva a autorização anterior', async () => {
  await render()
  mock.respostas.operacoes = { error: new Error('Consulta falhou') }
  await render(true, 1)
  expect(container.querySelector('button')!.disabled).toBe(true)
  expect(container.textContent).toContain('Consulta falhou')
})
