import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import type { DadosUsuario } from '../types'

type Props = { usuario: DadosUsuario; tipo: 'execucoes' | 'demandas'; registro: { id: string; responsavel_id: string | null; data_prevista: string | null; operacao_id: string | null; status: string }; atualizado: () => Promise<void> }
const local = (s: string | null) => { if (!s) return ''; const d = new Date(s); return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16) }
export default function GestaoAtividade({ usuario, tipo, registro, atualizado }: Props) {
  const [pessoas, setPessoas] = useState<{ id: string; nome: string }[]>([])
  const [operacoes, setOperacoes] = useState<{ id: string; nome: string }[]>([])
  const [responsavel, setResponsavel] = useState(registro.responsavel_id || '')
  const [prazo, setPrazo] = useState(local(registro.data_prevista))
  const [operacao, setOperacao] = useState(registro.operacao_id || '')
  const [motivo, setMotivo] = useState('')
  const [mensagem, setMensagem] = useState('')
  const [salvando, setSalvando] = useState(false)
  const [reabrir, setReabrir] = useState(false)
  const gestor = ['ADMIN', 'DIRETORIA', 'LIDER', 'GESTOR', 'GERENTE'].includes(usuario.perfil)
  useEffect(() => {
    if (!gestor) return
    let cancelado = false
    Promise.all([supabase.rpc('nexo_diretorio'), supabase.from('operacoes').select('id,nome').eq('ativo', true).order('nome')]).then(([p, o]) => {
      if (cancelado) return
      if (p.error || o.error) setMensagem('Não foi possível carregar as opções de gestão.')
      else { setPessoas(p.data || []); setOperacoes(o.data || []) }
    })
    return () => { cancelado = true }
  }, [gestor])
  if (!gestor) return null
  async function salvar(e: React.FormEvent) {
    e.preventDefault(); setSalvando(true); setMensagem('')
    try {
      const { error } = await supabase.rpc('nexo_gerir_atividade', { p_tipo: tipo, p_id: registro.id, p_responsavel: responsavel, p_prazo: prazo ? new Date(prazo).toISOString() : null, p_motivo: motivo.trim(), p_operacao: operacao || null, p_reabrir: reabrir })
      if (error) throw error
      await atualizado(); setMensagem('Alteração registrada com justificativa.'); setMotivo('')
    } catch (e) { setMensagem((e as { message?: string }).message || 'Não foi possível salvar.') }
    finally { setSalvando(false) }
  }
  return <details className="panel"><summary>Gestão: responsável, prazo e justificativa</summary><form onSubmit={salvar} className="form-grid">
    <label>Responsável<select required value={responsavel} onChange={e => setResponsavel(e.target.value)}><option value="">Selecione</option>{pessoas.map(p => <option key={p.id} value={p.id}>{p.nome}</option>)}</select></label>
    <label>Prazo<input type="datetime-local" value={prazo} onChange={e => setPrazo(e.target.value)} /></label>
    {tipo === 'demandas' && <label>Operação<select value={operacao} onChange={e => setOperacao(e.target.value)}><option value="">Sem operação</option>{operacoes.map(o => <option key={o.id} value={o.id}>{o.nome}</option>)}</select></label>}
    <label>Justificativa<input required value={motivo} onChange={e => setMotivo(e.target.value)} placeholder="Por que esta alteração é necessária?" /></label>
    {tipo === 'execucoes' && ['CONCLUIDA', 'CANCELADA'].includes(registro.status) && <label><input type="checkbox" checked={reabrir} onChange={e => setReabrir(e.target.checked)} />Reabrir execução</label>}
    <p>Somente responsáveis do seu escopo. Demandas vinculadas acompanham a execução. Faça a redistribuição e a reabertura na execução.</p>
    <button disabled={salvando} type="submit">{salvando ? 'Salvando…' : 'Salvar alteração'}</button>{mensagem && <p role="status">{mensagem}</p>}
  </form></details>
}
