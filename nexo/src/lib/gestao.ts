export type ExecucaoGestao = {
  id: string
  titulo?: string
  status: string
  prioridade?: string
  data_prevista: string | null
  data_inicio?: string | null
  data_conclusao?: string | null
  responsavel_id: string | null
  operacao_id: string
  percentual_conclusao?: number
}

export type RetrabalhoGestao = {
  id: string
  execucao_id: string
  pessoa_origem_id?: string | null
  responsavel_correcao_id?: string | null
  status: string
}

export type BloqueioGestao = {
  id: string
  execucao_id: string
  ativo: boolean
  motivo?: string | null
  iniciado_em?: string | null
  finalizado_em?: string | null
}

export type DependenciaGestao = {
  id: string
  execucao_id: string
  ativo: boolean
  tipo_dependencia?: string | null
  motivo?: string | null
  impacto?: string | null
  entidade_externa?: string | null
  previsao_retorno?: string | null
  proxima_acao?: string | null
  iniciado_em?: string | null
  finalizado_em?: string | null
}

export type CargaGestao = {
  pessoa_id: string
  percentual_carga: number | null
  tempo_estimado_minutos?: number | null
}

export function estaAtrasada(execucao: ExecucaoGestao) {
  if (!execucao.data_prevista || ['CONCLUIDA', 'CANCELADA'].includes(execucao.status)) return false
  return new Date(execucao.data_prevista).getTime() < Date.now()
}

export function horasEntre(inicio?: string | null, fim?: string | null) {
  if (!inicio) return 0
  const a = new Date(inicio).getTime()
  const b = fim ? new Date(fim).getTime() : Date.now()
  return Math.max(0, (b - a) / 3600000)
}

export function classificacaoScore(score: number) {
  if (score >= 90) return { label: 'Excelente', nivel: 'excelente', emoji: '🟢' }
  if (score >= 80) return { label: 'Muito bom', nivel: 'bom', emoji: '🟢' }
  if (score >= 70) return { label: 'Atenção', nivel: 'atencao', emoji: '🟡' }
  if (score >= 60) return { label: 'Crítico', nivel: 'critico', emoji: '🟠' }
  return { label: 'Muito crítico', nivel: 'muito-critico', emoji: '🔴' }
}

export function scorePessoa(params: {
  pessoaId: string
  execucoes: ExecucaoGestao[]
  retrabalhos: RetrabalhoGestao[]
  bloqueios: BloqueioGestao[]
  dependencias: DependenciaGestao[]
  carga: CargaGestao[]
}) {
  const { pessoaId, execucoes, retrabalhos, bloqueios, dependencias, carga } = params
  const minhas = execucoes.filter((x) => x.responsavel_id === pessoaId)
  const concluidas = minhas.filter((x) => x.status === 'CONCLUIDA')
  const abertas = minhas.filter((x) => !['CONCLUIDA', 'CANCELADA'].includes(x.status))
  const atrasadas = abertas.filter(estaAtrasada)
  const concluidasNoPrazo = concluidas.filter((x) => !x.data_prevista || !x.data_conclusao || new Date(x.data_conclusao) <= new Date(x.data_prevista))

  const ids = new Set(minhas.map((x) => x.id))
  const depsExternas = dependencias.filter((d) => ids.has(d.execucao_id) && d.ativo && ['FORNECEDOR', 'CLIENTE', 'SISTEMA', 'INFORMACAO', 'APROVACAO', 'OUTRO'].includes(d.tipo_dependencia || ''))
  const atrasosComDependencia = atrasadas.filter((x) => depsExternas.some((d) => d.execucao_id === x.id)).length
  const atrasosResponsabilidade = Math.max(0, atrasadas.length - atrasosComDependencia)

  const retrabalhoOrigem = retrabalhos.filter((r) => r.pessoa_origem_id === pessoaId && r.status !== 'CANCELADO').length
  const bloqueiosAtivos = bloqueios.filter((b) => ids.has(b.execucao_id) && b.ativo).length
  const cargaTotal = carga.filter((c) => c.pessoa_id === pessoaId).reduce((s, c) => s + (Number(c.percentual_carga) || 0), 0)

  const prazoBase = concluidas.length ? (concluidasNoPrazo.length / concluidas.length) : (minhas.length ? Math.max(0, 1 - atrasosResponsabilidade / Math.max(1, abertas.length)) : 1)
  const prazo = Math.round(25 * Math.max(0, Math.min(1, prazoBase)))

  const qualidadeRatio = minhas.length ? Math.max(0, 1 - retrabalhoOrigem / Math.max(1, minhas.length)) : 1
  const qualidade = Math.round(20 * qualidadeRatio)

  const sla = Math.round(15 * Math.max(0, Math.min(1, prazoBase)))

  const concluidasPeso = concluidas.length
  const cargaIdeal = cargaTotal <= 0 ? 75 : cargaTotal
  const produtividadeRatio = Math.min(1, concluidasPeso / Math.max(1, concluidasPeso + abertas.length * 0.35))
  const produtividade = Math.round(15 * Math.max(0.55, produtividadeRatio))

  let cargaScore = 10
  if (cargaIdeal > 120) cargaScore = 5
  else if (cargaIdeal > 100) cargaScore = 7
  else if (cargaIdeal < 45 && minhas.length > 0) cargaScore = 8

  const bloqueioScore = Math.max(0, 5 - Math.min(5, bloqueiosAtivos))
  const retrabalhoScore = Math.max(0, 5 - Math.min(5, retrabalhoOrigem * 2))
  const regularidade = atrasosResponsabilidade === 0 ? 5 : Math.max(0, 5 - atrasosResponsabilidade)

  const score = Math.max(0, Math.min(100, prazo + qualidade + sla + produtividade + cargaScore + bloqueioScore + retrabalhoScore + regularidade))

  const impactos: { texto: string; peso: number }[] = []
  if (atrasosResponsabilidade) impactos.push({ texto: `${atrasosResponsabilidade} atraso(s) sob responsabilidade direta`, peso: atrasosResponsabilidade * 5 })
  if (retrabalhoOrigem) impactos.push({ texto: `${retrabalhoOrigem} retrabalho(s) com origem na execução`, peso: retrabalhoOrigem * 6 })
  if (cargaTotal > 100) impactos.push({ texto: `sobrecarga de ${Math.round(cargaTotal)}%`, peso: Math.round(cargaTotal - 100) })
  if (bloqueiosAtivos) impactos.push({ texto: `${bloqueiosAtivos} bloqueio(s) ativo(s)`, peso: bloqueiosAtivos * 3 })
  if (atrasosComDependencia) impactos.push({ texto: `${atrasosComDependencia} atraso(s) associados a dependência externa`, peso: 1 })
  impactos.sort((a, b) => b.peso - a.peso)

  return {
    score,
    classificacao: classificacaoScore(score),
    prazo,
    qualidade,
    sla,
    produtividade,
    cargaScore,
    bloqueioScore,
    retrabalhoScore,
    regularidade,
    cargaTotal: Math.round(cargaTotal),
    abertas: abertas.length,
    concluidas: concluidas.length,
    atrasadas: atrasadas.length,
    atrasosResponsabilidade,
    atrasosComDependencia,
    retrabalhoOrigem,
    bloqueiosAtivos,
    principalImpacto: impactos[0]?.texto || 'Sem impacto relevante identificado',
  }
}
