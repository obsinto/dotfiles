# CS2 GPU hang fix — RX 7600 (RDNA3 / amdgpu)

Mitigação para os travamentos do Pop!_OS ao jogar **Counter-Strike 2** numa
**Radeon RX 7600 (Navi 33, RDNA3)**. Aplicada em 2026-06-20.

---

## 1. Sintoma

Durante o CS2 a tela congela alguns segundos e **toda a sessão do desktop
COSMIC reinicia** (todos os apps fecham de uma vez, sem reboot da máquina).
Às vezes o CS2 fecha sozinho; em casos piores vira freeze duro.

> Não é falta de memória (OOM) nem aba do Chrome. É a GPU.

## 2. Causa raiz

A fila gráfica da GPU (`gfx_0.0.0`) para de sinalizar trabalho concluído →
o reset "leve" via MES falha → o driver cai pro **reset total da GPU**, que
derruba o compositor `cosmic-comp` (erro 137) e reinicia a sessão.

Trecho típico do `journalctl -b -k`:

```
ring gfx_0.0.0 timeout, signaled seq=..., emitted seq=...
amdgpu: MES failed to respond to msg=RESET
amdgpu: reset via MES failed and try pipe reset -110
amdgpu: GPU reset(1) succeeded!
[drm] device wedged, but recovered through reset
```

Em RDNA3 isso quase sempre estoura nas **transições de clock/power-state**
(entrar/sair de estados de economia tipo GFXOFF) sob a carga em rajadas do CS2.

### Como confirmar que foi isso (não memória)

```bash
journalctl -b -k | grep -iE "gfx.*timeout|GPU reset|device wedged"
journalctl -b   | grep -iE "out of memory|oom-kill"   # deve vir VAZIO
sensors | grep -iA6 amdgpu                              # térmica (não é o caso aqui)
```

## 3. A correção (pin de clock só durante o jogo)

Fixa a GPU em `power_dpm_force_performance_level=high` **enquanto o CS2 roda**
e volta pra `auto` ao sair. Sem a oscilação de clock, a transição que trava
não acontece. Só afeta a GPU durante o jogo — o resto do desktop fica normal.

Três peças:

| Arquivo | Vai para | O quê |
|---|---|---|
| `cs2-stable` | `~/.local/bin/cs2-stable` | wrapper que pina/solta o clock (trap restaura no exit/crash) |
| `99-rx7600-perf-writable.rules` | `/etc/udev/rules.d/` | dá `g+w` no sysfs pro grupo `render`, pra pinar sem sudo |
| `zenity-askpass` | `~/.local/bin/zenity-askpass` | helper de senha pra `sudo -A` em sessão Wayland |

> A GPU discreta é `0000:03:00.0` (a iGPU do 9600X é `0e00`). O usuário já está
> no grupo `render`, por isso a regra usa esse grupo.

## 4. Instalar

```bash
cd ~/Documents/cs2-gpu-hang-fix
./install.sh          # copia scripts, instala a regra udev (pede senha no zenity)
```

Depois, **passo manual no Steam** (precisa ser na UI porque o Steam aberto
sobrescreve o config em disco):

> Steam → botão direito no CS2 → **Propriedades** → **Opções de Inicialização**:

```
SDL_AUDIODRIVER=pulseaudio RADV_DEBUG=zerovram /home/deyvid/.local/bin/cs2-stable %command% +fps_max 150
```

A ordem importa: env vars **antes** do `%command%`, args do jogo (`+fps_max`)
**depois**.

## 5. Verificar

```bash
# permissão (esperado: root render, rw-rw-r--)
ls -l /sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level

# ciclo sem sudo (deve imprimir high e voltar pra auto)
~/.local/bin/cs2-stable sh -c 'cat /sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level'
cat /sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level
```

Durante uma partida, em outro terminal:

```bash
watch -n1 cat /sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level
# deve mostrar 'high' com o CS2 aberto e 'auto' depois de fechar
```

## 6. Reverter

```bash
cd ~/Documents/cs2-gpu-hang-fix
./uninstall.sh
```

E remover `/home/deyvid/.local/bin/cs2-stable` das Opções de Inicialização do CS2.

## 7. Se ainda travar (próximos passos)

A correção foi para a hipótese de transição de power-state. Se persistir:

1. **Desabilitar GFXOFF** (mais invasivo, afeta o desktop inteiro):
   teste em runtime e, se ajudar, torne persistente.
   ```bash
   # achar o índice do dri certo (card da 03:00.0)
   sudo sh -c 'echo 0 > /sys/kernel/debug/dri/<N>/amdgpu_gfxoff'
   ```
2. **Firmware do MES**: checar `linux-firmware` mais novo (o log mostra
   `MES failed to respond` — caminho de reset que teve correções recentes).
3. Capar mais o FPS (ex.: `+fps_max 141`, logo abaixo dos ~144 Hz do monitor)
   e/ou ligar vsync, pra suavizar as rajadas de carga.

## Ambiente em que foi feito (2026-06-20)

- GPU: AMD RX 7600 (Navi 33, RDNA3, gfx_v11) em `0000:03:00.0`
- Kernel: `6.18.7-76061807-generic`
- Mesa / RADV: `25.2.8`
- Desktop: COSMIC (Wayland), compositor `cosmic-comp`
- Monitor: 1920x1080 @ ~144 Hz
