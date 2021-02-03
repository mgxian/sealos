// Copyright © 2019 NAME HERE <EMAIL ADDRESS>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cmd

import (
	"fmt"
	"github.com/fanux/sealos/cert"
	"github.com/fanux/sealos/pkg/logger"
	"github.com/spf13/cobra"
	"os"
)

// initCmd represents the init command
var kubeConfigCmd = &cobra.Command{
	Use:   "kubeconfig",
	Short: "generate kubeconfig",
	Long:  `generate kubeconfig for kube-controller-manager kube-scheduler kubelet admin`,
	Run: func(cmd *cobra.Command, args []string) {
		CreateKubeConfig()
	},
}

var (
	ApiServer     string
	CertPath      string
	KubeConfigDir string
)

func init() {
	rootCmd.AddCommand(kubeConfigCmd)
	kubeConfigCmd.Flags().StringVar(&CertPath, "cert-path", ".sealos/pki", "kubernetes cert file path")
	kubeConfigCmd.Flags().StringVar(&ApiServer, "api-server", "1.1.1.1", "kubernetes api server address")
	kubeConfigCmd.Flags().StringVar(&KubeConfigDir, "kubeconfig-dir", ".sealos", "sealos config directory")
}

func CreateKubeConfig() {
	certConfig := cert.Config{
		Path:     CertPath,
		BaseName: "ca",
	}

	controlPlaneEndpoint := fmt.Sprintf("https://%s:6443", ApiServer)

	hostname := "whatever"
	err := cert.CreateJoinControlPlaneKubeConfigFiles(KubeConfigDir,
		certConfig, hostname, controlPlaneEndpoint, "kubernetes")
	if err != nil {
		logger.Error("generator kubeconfig failed %s", err)
		os.Exit(-1)
	}
}
